library messageQueuingSystem.Mqs;

import 'dart:io';
import "dart:isolate";
import "dart:async";
import 'dart:convert';

import "WebSocketServer.dart";
import "Enqueuer.dart";
import "Dequeuer.dart";
import "action/Action.dart";
import "message/MessageUtil.dart";

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
 *
 */

/**
 * Incoming Message from IsolateSystem:
 *  * Dequeue Message: {targetQueue: isolateSystem2.ping, action: action.dequeue}
 *
 * Outgoing Message To Dequeuer:
 *  * {action: action.dequeue, topic: isolateSystem2.ping, socket: 1033445818}
 *
 * Incoming Message from Dequeuer:
 *  *
 *
 * Incoming Message From IsolateSystem:
 *  * Enqueue Message:
 *  {targetQueue: isolateSystem.helloPrinter, action: action.enqueue, payload: {message: My Message #4983, replyTo: isolateSystem.helloPrinter2}}
 *
 * Outgoing Message to Enqueuer:?
 *  {targetQueue: isolateSystem.helloPrinter, action: action.enqueue, payload: {message: My Message #4983, replyTo: isolateSystem.helloPrinter2}}
 *
 */

class Mqs {
  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;

  static const String DEFAULT_LOGIN = "guest";//"fdd";
  static const String DEFAULT_PASSWORD = "guest";//"pass";

  static const String ISOLATE_SYSTEM = "senderType.isolateSystem";

  //TODO: needs refactoring

  //TODO: persistent queue - "topic/name"?
  static const String TOPIC = "/queue";

  static Map<String, String> HEADERS = null;//{'delivery-mode':'2'};//{'reply-to' : '/queue/test'};

  List<_Dequeuer> _dequeuers;

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

  List bufferMessagesToDequeuer;
  List bufferMessagesToEnqueuer;

  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:DEFAULT_LOGIN, password:DEFAULT_PASSWORD}) {
    _subscribedTopics = new List();
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _dequeuers = new List();
    _connectedSystems = new List();

    bufferMessagesToDequeuer = new List();
    bufferMessagesToEnqueuer = new List();

    _out("Starting up enqueuer...");
    connectionArgs = [host, port, username, password];
    _startEnqueuerIsolate(connectionArgs);

    wss = new WebSocketServer(int.parse(listeningPort), webSocketPath, _onConnect, _onData, _onDisconnect);
  }

  _onReceive(var message) {
    _out("MQS: $message");
    if(message is Map) {
      String senderType = MessageUtil.getSenderType(message);

      switch(senderType) {
        case ISOLATE_SYSTEM:
          _handleMessageFromIsolateSystem(message);
          break;

        case Enqueuer.ENQUEUER:
          _handleMessageFromEnqueuer(message['message']);
          break;

        case Dequeuer.DEQUEUER:
          _handleMessageFromDequeuer(message);
          break;

        default:
          break;
      }
    }
  }


  /**
   * Incoming message is of type: (from _onData)
   *
   * For Dequeue (from _onData):
   * {senderType:senderType.isolateSystem, isolateSystmeId: anySystem, message: {targetQueue: isolateSystem.helloPrinter, action: action.dequeue}}
   *
   * To Dequeuer:
   *
   * For Enqueue (from _onData):
   *
   * To Enqueuer:
   *
   */
  _handleMessageFromIsolateSystem(var fullMessage) {
    var message = fullMessage['message'];
    _out("MQS: handling External Messages $fullMessage");
    String action = MessageUtil.getAction(message);
    String topic = MessageUtil.getTargetQueue(message);
    if(topic != null) {
      switch(action) {
        case Action.DEQUEUE:
          String socket = fullMessage['socket'];
          String isolateSystemId = fullMessage['isolateSystemId'];
          _dequeueMessage(isolateSystemId, topic, socket);
          break;
        case Action.ENQUEUE:
          var payload = MessageUtil.getPayload(fullMessage);
          _enqueueMessage(topic, payload);
          break;
        default:
          _out("MQS: Unknown Action -> $action");
      }
    } else {
      _out("MQS: Topic | Target Queue is null");
    }
  }


  _handleMessageFromEnqueuer(var message) {
    if(message is SendPort) {
      _enqueuerSendPort = message;
    }
  }

  _oldhandleDequeuerMessages(var message) {
    String topic = message['topic'];
    _Dequeuer dequeuer = _getDequeuerByTopic(topic);

    if(message['message'] is SendPort) {
      dequeuer.sendPort = message['message'];
    } else {
      _out("${dequeuer.isolateSystem.sockets.keys} sockets in -> ${dequeuer.isolateSystem.id}");
      String key = message['socket'].toString();


      if(dequeuer.isolateSystem.sockets.containsKey(key)) {
        message.remove('socket');

        dequeuer.isolateSystem.sockets[key].add(
          JSON.encode(message)
        );
      } else {
        // re-queue the message because requester is no longer available
        _out("Requeuing ${message['message']} because ${message['socket']} was not available");
        _enqueue(topic, message['message']);
      }
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
      isolateSystem.sockets[socket.hashCode.toString()] = socket;
    } else {
      _IsolateSystem system = new _IsolateSystem(isolateSystemId, socket);
      _connectedSystems.add(system);
      _updateIsolateSystemInDequeuers(system);
    }
  }

  /**
   * Simply adds hash of incoming socket, only if it is a dequeue request, to identify where to reply
   *
   * Receives message in format:
   * {targetQueue: isolateSystem.helloPrinter, action: action.dequeue}
   *
   * Sends message to self in format:
   * {senderType:senderType.isolateSystem, isolateSystmeId: anySystem, message: {targetQueue: isolateSystem.helloPrinter, action: action.dequeue}}
   *
   * Same for enqueue
   *
   */
  _onData(WebSocket socket, String isolateSystemId, var msg) {
    var message = JSON.decode(msg);
    _out("MQS: ondata: $message");
    _me.send({'senderType':ISOLATE_SYSTEM, 'isolateSystemId':isolateSystemId, 'socket':socket.hashCode.toString(), 'message':message});
  }

  _onDisconnect(WebSocket socket, String isolateSystemId) {
    _IsolateSystem isolateSystem = _getIsolateSystemById(isolateSystemId);
    if(isolateSystem != null) {
      if(isolateSystem.sockets.containsKey(socket.hashCode.toString())) {
        isolateSystem.sockets.remove(socket.hashCode.toString());
      }
      if(isolateSystem.sockets.length == 0) {
        _connectedSystems.remove(isolateSystem);
      }
    }
    socket.close();
  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, _receivePort.sendPort);
  }

  Future<Isolate> _startDequeuerIsolate(List<String> args) {
    return Isolate.spawnUri(dequeueIsolate, args, _receivePort.sendPort);
  }

  bool _enqueueMessage(String topic, String payload) {
    _out("ENQ: $payload to $topic");
    Map msg = {'topic':topic, 'action':Action.ENQUEUE, 'message': payload};
    if(_enqueuerSendPort != null) {
      _enqueuerSendPort.send(msg);
      return true;
    }
    return false;
  }

  void _dequeueMessage(String systemId, String topic, String socket) {
    Map messageForDequeuer = {'action':Action.DEQUEUE, 'topic':topic, 'socket':socket};

    _Dequeuer dequeuer = _getDequeuerByTopic(topic);
    if(dequeuer == null) {

      dequeuer = new _Dequeuer(topic, systemId, _getIsolateSystemById(systemId));
      _dequeuers.add(dequeuer);
      List temp  = new List();
      temp.addAll(connectionArgs);
      temp.add(topic);

      _startDequeuerIsolate(temp);
      bufferMessagesToDequeuer.add(messageForDequeuer);
    } else if(dequeuer.sendPort != null) {
      dequeuer.sendPort.send(messageForDequeuer);
    } else {
      bufferMessagesToDequeuer.add(messageForDequeuer);
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
      _out("Updating socket for ${dequeuer.topic} of $system");
      dequeuer.system = system;
    }
  }

  _out(String text) {
    print(text);
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
