library messageQueuingSystem.Mqs;

import 'dart:io';
import "dart:isolate";
import "dart:async";
import 'dart:convert';

import "WebSocketServer.dart";
import "Enqueuer.dart";
import "Dequeuer.dart";

/**
 *
 * Code Hack:
 * stomp_impl.dart : 299 (_subscribe())
 * headers["prefetch-count"] = "1";
 *
 * Oct 5, 2014
 * MQS should handle at webSocket connections with three subsystems:
 *  1. over STOMP with Message Broker System
 *    - as a client
 *    - handled by stomp package
 *
 *  2. With Registry
 *    - as a client
 *
 *  3. With Isolate Systems
 *    - as a Server
 *    - each IsolateSystem opens a webSocket connection with MQS
 *
 * Maintain list of subscribed topics,
 * spawn new isolate to listen on given topic if one doesnot exist yet
 *
 * Oct 13, 2014
 * If a connection with rabbitmq is lost, the buffer should be cleared immediately,
 * so that a message is not delivered twice even if was not ack'ed
 *
 * Assumes that an Isolate System connects to "ws://<ip>/mqs/<isolateSystemId>"
 *
 *  == some thoughts ==> RESOLVED !
 * What if there are many instances of same isolate system running in different servers
 * Maintain list of sockets for an isolate system
 * so systemId and socket together can determine where to send reply
 * if socket is not available at the time of replying, send it to any of them?
 * to find out which socket when msg is dequeued, pass along socket's_hash id or assign some id to socket?
 *
 * remove socket on disconnect and add on new connection
 * if this is not taken care of, each request from anywhere
 * will result in sending of messages only to latest connected socket
 */

class Mqs {

  static const String DEQUEUE = "action.dequeue";
  static const String ENQUEUE = "action.enqueue";

  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;

  static const String DEFAULT_LOGIN = "fdd";
  static const String DEFAULT_PASSWORD = "pass";

  static const String ISOLATE_SYSTEM = "senderType.isolateSystem";

  //static const String GUEST_LOGIN = "guest";
  //static const String GUEST_PASSWORD = "guest";

  //TODO: needs refactoring

  //TODO: persistent queue - "topic/name"?
  //static const String TOPIC = "/queue/testA";
  static const String TOPIC = "/queue";
  static Map<String, String> HEADERS = null;//{'delivery-mode':'2'};//{'reply-to' : '/queue/test'};

  List<_Dequeuer> _dequeuers;

//  ReceivePort receivePortEnqueue;
//  ReceivePort receivePortDequeue;

  ReceivePort _receivePort;
  SendPort _enqueuerSendPort;
  SendPort _me;

  List<String> _subscribedTopics;

  Uri enqueueIsolate = Uri.parse("Enqueuer.dart");
  Uri dequeueIsolate = Uri.parse("Dequeuer.dart");

  WebSocketServer wss;

  String webSocketPath = "/mqs";
  String listeningPort = "42043";

  List<String> connectionArgs;
  List<_IsolateSystem> _connectedSystems;

  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:DEFAULT_LOGIN, password:DEFAULT_PASSWORD}) {
    _subscribedTopics = new List();
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _dequeuers = new List();
    _connectedSystems = new List();

    print("Starting up enqueuer...");
    connectionArgs = [host, port, username, password];
    _startEnqueuerIsolate(connectionArgs);

    wss = new WebSocketServer(int.parse(listeningPort), webSocketPath, _onConnect, _onData, _onDisconnect);
  }

  _onReceive(var message) {
    print("MQS: $message");
    if(message is Map) {
      String senderType = message['senderType'];
      switch(senderType) {
        case Enqueuer.ENQUEUER:
          _handleEnqueuerMessages(message['message']);
          break;
        case Dequeuer.DEQUEUER:
          _handleDequeuerMessages(message);
          break;
        case ISOLATE_SYSTEM:
          _handleExternalMessages(message);
          break;
        default:
          break;
      }
    }
  }

  _handleEnqueuerMessages(var message) {
    if(message is SendPort) {
      _enqueuerSendPort = message;
    }
  }

  _handleDequeuerMessages(var message) {
    _Dequeuer dequeuer = _getDequeuerByTopic(message['topic']);
    if(message['message'] is SendPort) {
      print("Received send port from dequeuer !");
      dequeuer.sendPort = message['message'];
    } else {
      //send the message
      // using specific topic

      print("Send via websocket : ${message['message']} to ${message['socket']}");
      // somehow identify the socket

      print("${dequeuer.isolateSystem.sockets.keys} sockets in -> ${dequeuer.isolateSystem.id}");

      String key = message['socket'];
      dequeuer.isolateSystem.sockets[key.toString()].add(JSON.encode(message['message']));
    }
  }

  /**
   * Expects message of type:
   * {'senderId':"isolateSystem", 'action':"action.enqueue", 'payload':"message"}
   */
  _handleExternalMessages(var fullMessage) {
    //handle messages from
    var message = fullMessage['message'];
    print("MQS: handling External Messages");
    String isolateSystemId = fullMessage['senderIsolateSystemId'];
    String senderId = message['senderId'];
    String topic = isolateSystemId + "." + senderId;
    String action = message['action'];

    switch(action) {
      case DEQUEUE:
        _dequeue(topic, fullMessage);
        break;
      case ENQUEUE:
        var payload = message['payload'];
        _enqueue(topic, payload, fullMessage);
        break;
      default:
        print("Unknown action -> $action");
    }

  }

  /**
   * Separate websocket path for each isolatesystem ?
   * then we can use onConnect for adding / updating sockets in dequeuers
   * using systemId
   * TODO: handle if multiple system with same ID tries to connect
   *
   */
  _onConnect(WebSocket socket, String isolateSystemId) {
    _IsolateSystem isolateSystem = _getIsolateSystemById(isolateSystemId);
    if (isolateSystem != null) {
      print("Adding more sockets...");
      isolateSystem.sockets[socket.hashCode.toString()] = socket;
      print("Sockets Connected : ${isolateSystem.sockets.keys}");
    } else {
      _IsolateSystem system = new _IsolateSystem(isolateSystemId, socket);
      _connectedSystems.add(system);
      _updateIsolateSystemInDequeuers(system);
    }
  }

  /**
   * After client reconnects
   * WebSocket needs to be updated !
   *
   * on disconnect, remove isolateSystem itself and also from dequeuers
   * on reconnect, add isolateSystem and also to dequeuers
   */
  _onData(WebSocket socket, String isolateSystemId, var msg) {
    var message = JSON.decode(msg);
    _me.send({'senderType':ISOLATE_SYSTEM, 'senderIsolateSystemId':isolateSystemId, 'socket':socket.hashCode, 'message':message});
  }

  _onDisconnect(WebSocket socket, String isolateSystemId) {
    socket.close();
    _IsolateSystem isolateSystem = _getIsolateSystemBySocket(socket);
    if(isolateSystem != null) {
      //_connectedSystems.remove(isolateSystem);
      if(isolateSystem.sockets.containsKey(socket.hashCode)) {
        print("Removing socket: ${socket.hashCode}");
        isolateSystem.sockets.remove(socket.hashCode);
      }
    }
  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, _receivePort.sendPort);
  }

  Future<Isolate> _startDequeuerIsolate(List<String> args) {
    return Isolate.spawnUri(dequeueIsolate, args, _receivePort.sendPort);
  }

  _enqueue(String topic, String payload, String fullMessage) {
    Map msg = {'topic':topic, 'action':Mqs.ENQUEUE, 'message': payload};
    if(_enqueuerSendPort == null) {
      _me.send(fullMessage); //cyclic buffer
    } else {
      _enqueuerSendPort.send(msg);
    }
  }

  void _dequeue(String topic, var fullMessage) {
    _Dequeuer dequeuer = _getDequeuerByTopic(topic);
    String systemId = topic.split('.').first.split('/').last;
    String socket = fullMessage['socket'];
    if(dequeuer == null) {
      dequeuer = new _Dequeuer(topic, systemId, _getIsolateSystemById(systemId));
      _dequeuers.add(dequeuer);
      print("HANDLE DQ: ${dequeuer.isolateSystem.id}");

      List temp  = new List();
      temp.addAll(connectionArgs);
      temp.add(topic);

      _startDequeuerIsolate(temp).then((_) {
        _me.send(fullMessage);
      });

    } else if(dequeuer.sendPort != null) {
      dequeuer.sendPort.send({'action':Mqs.DEQUEUE, 'topic':topic, 'socket':socket});
    } else {
      _me.send(fullMessage);
    }
  }

  _Dequeuer _getDequeuerByTopic(String topic) {
    for(final _Dequeuer dequeuer in _dequeuers) {
      if(topic == dequeuer.topic) {
        return dequeuer;
      }
    }
    return null;
  }

  List<_Dequeuer> _getDequeuersByIsolateSystemId(String systemId) {
    List<_Dequeuer> dequeuers = new List();

    for(final _Dequeuer dequeuer in _dequeuers) {
      print("EACH DQ:${dequeuer.topic} => ${dequeuer.isolateSystemId} vs systemid = ${dequeuer.isolateSystem.id}");
      if(dequeuer.isolateSystemId == systemId) {
        dequeuers.add(dequeuer);
      }
    }
    return dequeuers;
  }


  _IsolateSystem _getIsolateSystemById(String systemId) {
    for(_IsolateSystem isolateSystem in _connectedSystems) {
      if(isolateSystem.id == systemId) {
        return isolateSystem;
      }
    }
    return null;
  }

  _IsolateSystem _getIsolateSystemBySocket(WebSocket socket) {
    for(_IsolateSystem isolateSystem in _connectedSystems) {
      if(isolateSystem.sockets.containsKey(socket.hashCode)) {
        return isolateSystem;
      }
    }
    return null;
  }

  _removeSystemFromDequeuers(_IsolateSystem system) {
    for(_Dequeuer dequeuer in _dequeuers) {
      if (dequeuer.isolateSystem.id == system.id) {
        dequeuer.system = null;
      }
    }
  }

  _updateIsolateSystemInDequeuers(_IsolateSystem system) {
    for(_Dequeuer dequeuer in _getDequeuersByIsolateSystemId(system.id)) {
      print("Updating socket for ${dequeuer.topic} of $system");
      dequeuer.system = system;
    }
  }
}

/**
 * Start the Message Queuing System
 */
main() {
  Mqs mqs = new Mqs(host:"127.0.0.1", port:61613);
}

class _IsolateSystem {
  String _id;
  Map<String, WebSocket> _sockets;

  String get id => _id;
  set id(String value) => _id = value;

  Map<String, WebSocket> get sockets => _sockets;
  set sockets(Map<String, WebSocket> value) => _sockets = value;

  _IsolateSystem(this._id, WebSocket socket) {
    if(_sockets == null){
      _sockets = new Map();
    }
    this._sockets[socket.hashCode.toString()] = socket;
  }


}

//multiple dequeuers can refer to same system
class _Dequeuer {
  String _topic;
  SendPort _sendPort;
  String _isolateSystemId;
  _IsolateSystem _isolateSystem;

  _Dequeuer(this._topic, this._isolateSystemId, this._isolateSystem);

  String get topic => _topic;
  set topic(String value) => _topic = value;

  SendPort get sendPort => _sendPort;
  set sendPort(SendPort value) => _sendPort = value;

  _IsolateSystem get isolateSystem => _isolateSystem;
  set system(_IsolateSystem value) => _isolateSystem = value;

  String get isolateSystemId => _isolateSystemId;
  set isolateSystemId(String value) => _isolateSystemId = value;
}
