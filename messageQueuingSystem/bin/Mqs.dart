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
 * Each Enqueuing and Dequeuing isolate for each TOPIC? or one for all
 * if One for all, then Dequeuer will have to subscribe to each
 * and the dequeuer should be able to figure out from where the message
 * was dequeued to find out correct "port" (by figuring out isolate system) & "to:" (by figuring out isolatepool)
 *
 * Maintain list of subscribed topics,
 * spawn new isolate to listen on given topic if one doesnot exist yet
 *
 * Oct 13, 2014
 * If a connection with rabbitmq is lost, the buffer should be cleared immediately,
 * so that a message is not delivered twice even if was not ack'ed
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

      print("Send via websocket : $message['message']");
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
    String senderId = message['senderId'];
    String system = senderId.split('.').first.split('/').last;
    String isolatePool = senderId.split('.').last;
    String action = message['action'];

    switch(action) {
      case DEQUEUE:
        _handleDequeue(senderId, fullMessage);
        break;
      case ENQUEUE:
        var payload = message['payload'];
        _handleEnqueue(senderId, payload, fullMessage);
        break;
      default:
        print("Unknown action -> $action");
    }

  }

  _onConnect(WebSocket socket) {

  }

  /**
   * After client reconnects
   * WebSocket needs to be updated !
   *
   * on disconnect, remove system itself and also from dequeuers
   * on reconnect, add system and also to dequeuers
   */
  _onData(WebSocket socket, var msg) {
    var message = JSON.decode(msg);
    //keep records of sockets here
    String senderId = message['senderId'];
    String systemId = senderId.split('.').first.split('/').last;
    if(_getSystemById(systemId) == null) {
      _IsolateSystem system = new _IsolateSystem(systemId, socket);
    }
    _me.send({'senderType':ISOLATE_SYSTEM, 'message':message});
  }

  _onDisconnect(WebSocket socket) {
    socket.close();
  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, _receivePort.sendPort);
  }

  _startDequeuerIsolate(List<String> args) {
    Isolate.spawnUri(dequeueIsolate, args, _receivePort.sendPort);
  }

  _handleEnqueue(String topic, String payload, String fullMessage) {
    Map msg = {'topic':topic, 'action':Mqs.ENQUEUE, 'message': payload};
    if(_enqueuerSendPort == null) {
      _me.send(fullMessage); //cyclic buffer
    } else {
      _enqueuerSendPort.send(msg);
    }
  }

  String _handleDequeue(String topic, var fullMessage) {
    _Dequeuer dequeuer = _getDequeuerByTopic(topic);
    String systemId = topic.split('.').first.split('/').last;
    if(dequeuer == null) {
      _Dequeuer _dequeuer = new _Dequeuer(topic, _getSystemById(systemId));
      _dequeuers.add(_dequeuer);

      List temp  = new List();
      temp.addAll(connectionArgs);
      temp.add(topic);

      _startDequeuerIsolate(temp);
    } else if(dequeuer.sendPort != null) {
      dequeuer.sendPort.send({
          'action':Mqs.DEQUEUE, 'topic':topic
      });
    } else {
      _me.send(fullMessage);
    }
  }

  _Dequeuer _getDequeuerByTopic(String topic) {
    for(final dequeuer in _dequeuers) {
      if(topic == dequeuer.topic) {
        return dequeuer;
      }
    }
    return null;
  }

  _IsolateSystem _getSystemById(String systemId) {
    for(_IsolateSystem system in _connectedSystems) {
      if(system.id == systemId) {
        return system;
      }
    }
    return null;
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
  WebSocket _socket;

  String get id => _id;
  set id(String value) => _id = value;

  WebSocket get socket => _socket;
  set socket(WebSocket value) => _socket = value;

  _IsolateSystem(this._id, this._socket);
}

//multiple dequeuers can refer to same system
class _Dequeuer {
  String _topic;
  SendPort _sendPort;
  _IsolateSystem _system;

  _Dequeuer(this._topic, this._system);

  String get topic => _topic;
  set topic(String value) => _topic = value;

  SendPort get sendPort => _sendPort;
  set sendPort(SendPort value) => _sendPort = value;

  _IsolateSystem get system => _system;
  set system(_IsolateSystem value) => _system = value;
}
