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
 * Assumes that an Isolate System connects to "ws://<ip>/mqs/<isolateSystemName>"
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
 * Outgoing Message To Isolatesystem:
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

  static const String TOPIC = "/queue";

  static Map<String, String> HEADERS = null;//{"persistent":"true"};//{'delivery_mode':'2'};//{'reply-to' : '/queue/test'};

  List<_Dequeuer> _dequeuers;

  ReceivePort _receivePort;
  SendPort _enqueuerSendPort;
  SendPort _me;

  Uri enqueueIsolate = Uri.parse("Enqueuer.dart");
  Uri dequeueIsolate = Uri.parse("Dequeuer.dart");

  WebSocketServer wss;

  String webSocketPath = "/mqs";
  String listeningPort = "42043";
  String prefetchCount = "1";

  List<String> connectionArgs;
  List<_IsolateSystem> _connectedSystems;

  List _bufferMessagesToDequeuer;
  List _bufferMessagesToEnqueuer;

  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:DEFAULT_LOGIN, password:DEFAULT_PASSWORD, prefetchCount:"1"}) {

    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    try {
      _receivePort.listen(_onReceive);
    } catch(e) {
      _log("Exception caught => $e");
    }
    _dequeuers = new List();
    _connectedSystems = new List();

    _bufferMessagesToDequeuer = new List();
    _bufferMessagesToEnqueuer = new List();

    this.prefetchCount = prefetchCount;
    print(prefetchCount);
    _log("Starting up enqueuer...");
    connectionArgs = [host, port, username, password];
    _startEnqueuerIsolate(connectionArgs);

    wss = new WebSocketServer(int.parse(listeningPort), webSocketPath, _onConnect, _onData, _onDisconnect);
  }

  _onReceive(var message) {
    _log("MQS: $message");
    if(MessageUtil.isValidMessage(message)) {
      if(message is String) {
        message = JSON.decode(message);
      } else if(message is List) {
        message = {'senderType': message[0], 'payload': message[1], 'topic': (message.length > 2) ? message[2] : null};
      }
      String senderType = MessageUtil.getSenderType(message);

      switch(senderType) {
        case ISOLATE_SYSTEM:
          _handleMessageFromIsolateSystem(message);
          break;

        case Enqueuer.ENQUEUER:
          _handleMessageFromEnqueuer(message['payload']);
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
   *
   * Incoming message for Dequeue (from _onData):
   * {senderType:senderType.isolateSystem, isolateSystmeId: anySystem, socket:12345, message: {targetQueue: isolateSystem.helloPrinter, action: action.dequeue}}
   *
   * To Dequeuer:
   * {'action':action.dequeue, 'topic':isolateSystem.helloPrinter, 'isolateSystemId':12345}
   *
   * Incoming message for Enqueue (from _onData):
   * {senderType: senderType.isolateSystem, isolateSystemName: anySystem, socket: 314505237, message: {targetQueue: isolateSystem.helloPrinter, payload: {message: My Message #1497, replyTo: isolateSystem.helloPrinter2}, action: action.enqueue}}
   *
   * To Enqueuer:
   * {'topic':topic, 'action':Action.ENQUEUE, 'payload': {message: My Message #1497, replyTo: isolateSystem.helloPrinter2}};
   */
  _handleMessageFromIsolateSystem(Map fullMessage) {
    var message = fullMessage['message'];
    _log("MQS: handling External Messages $fullMessage");

    String action = MessageUtil.getAction(message);
    String topic = MessageUtil.getTargetQueue(message);
    if(topic != null) {
      switch(action) {
        case Action.DEQUEUE:
          String isolateSystemId = fullMessage['isolateSystemId'];
          String isolateSystemName = fullMessage['isolateSystemName'];
          _dequeueMessage(isolateSystemName, topic, isolateSystemId, fullMessage);
          break;
        case Action.ENQUEUE:
          Map msg = {'topic':topic, 'action':Action.ENQUEUE, 'payload': MessageUtil.getPayload(message)};
          _enqueueMessage(msg, fullMessage);
          break;
        default:
          _log("MQS: Unknown Action -> $action");
      }
    } else {
      _log("MQS: Topic | Target Queue is null");
    }
  }

  /**
   * Message from Enqueuer is only SendPort
   */
  _handleMessageFromEnqueuer(var message) {
    if(message is SendPort) {
      _enqueuerSendPort = message;
      _flushBufferToEnqueuer();
    }
  }

  /**
   * Message From Dequeuer in Format:
   * From Dequeuer:
   * {senderType: senderType.dequeuer, topic: isolateSystem2.pong, payload: {message: {value: PING, count: 3}, replyTo: isolateSystem2/ping}, socket: 541578376}
   *
   */
  _handleMessageFromDequeuer(var message) {
    _log("MQS: From Dequeuer: $message");
    String topic = message['topic'];
    _Dequeuer dequeuer = _getDequeuerByTopic(topic);
    var payload = MessageUtil.getPayload(message);

    if(payload is SendPort) {
      dequeuer.sendPort = payload;
      _flushBufferToDequeuer();
    } else if(payload == null){
      if(message['action'] == "action.killed") {
//        _Dequeuer removedDeq = _getDequeuerByTopic(MessageUtil.getTopic(message));
//        _dequeuers.remove(removedDeq);
        String topic = MessageUtil.getTopic(message);
        _dequeuers.removeWhere((dequeuer) => dequeuer.topic == topic);
      }
    } else {
      _log("${dequeuer.isolateSystem.sockets.keys} sockets in -> ${dequeuer.isolateSystem.name}");
      String key = message['isolateSystemId'];

      if(dequeuer.isolateSystem.sockets.containsKey(key)) {
        message.remove('isolateSystemId');
        dequeuer.isolateSystem.sockets[key].add(JSON.encode(message));
      } else {
        // re-queue the message because requester is no longer available
        _log("Requeuing $message because ${message['isolateSystemId']} was not available");
        Map msg = {'topic':topic, 'action':Action.ENQUEUE, 'payload': payload};
        _enqueueMessage(msg, message);
      }
    }
  }

  /**
   * Each system connects with uniqueId.
   */
  _onConnect(WebSocket socket, String isolateSystemName, String isolateSystemId) {
    _IsolateSystem isolateSystem = _getIsolateSystemByName(isolateSystemName);
    if (isolateSystem != null) {
      isolateSystem.sockets[isolateSystemId] = socket;
    } else {
      _IsolateSystem system = new _IsolateSystem(isolateSystemName, isolateSystemId, socket);
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
  _onData(WebSocket socket, String isolateSystemName, String isolateSystemId, var msg) {
    var message = JSON.decode(msg);
    _log("MQS: ondata -> $message");
    _sendToSelf({'senderType':ISOLATE_SYSTEM, 'isolateSystemName':isolateSystemName, 'isolateSystemId':isolateSystemId, 'message':message});
  }

  _onDisconnect(WebSocket socket, String isolateSystemName, String isolateSystemId) {
    _IsolateSystem isolateSystem = _getIsolateSystemByName(isolateSystemName);
    if(isolateSystem != null) {
      if(isolateSystem.sockets.containsKey(isolateSystemId)) {
        isolateSystem.sockets.remove(isolateSystemId);
      }
      if(isolateSystem.sockets.length == 0) {
        _connectedSystems.remove(isolateSystem);
      }
    }
    socket.close();
  }

  void _enqueueMessage(Map message, Map fullMessage) {
    _log("MQS: Enqueuing message -> ${message['payload']} to ${message['topic']}");

    if(_enqueuerSendPort != null) {
      _sendToEnqueuer(message);
    } else {
      _bufferMessagesToEnqueuer.add(fullMessage);
    }
  }

  void _dequeueMessage(String isolateSystemName, String topic, String isolateSystemId, Map fullMessage) {
    Map messageForDequeuer = {'action':Action.DEQUEUE, 'topic':topic, 'isolateSystemId':isolateSystemId};
    _log("MQS: Dequeuing -> $messageForDequeuer");
    if(messageForDequeuer['topic'] == null)
      throw StackTrace;
    _Dequeuer dequeuer = _getDequeuerByTopic(topic);
    if(dequeuer == null) {
      dequeuer = new _Dequeuer(topic, isolateSystemName, _getIsolateSystemByName(isolateSystemName));
      _dequeuers.add(dequeuer);
      List temp  = new List();
      temp.addAll(connectionArgs);
      temp.add(topic);
      temp.add(prefetchCount);

      _startDequeuerIsolate(temp);
      _bufferMessagesToDequeuer.add(fullMessage);
    } else if(dequeuer.sendPort != null) {
      _sendToDequeuer(dequeuer, messageForDequeuer);
    } else {
      _bufferMessagesToDequeuer.add(fullMessage);
    }
  }

  void _sendToEnqueuer(var message) {
    _enqueuerSendPort.send(JSON.encode(message));
  }

  void _sendToDequeuer(_Dequeuer dequeuer, var message) {
    dequeuer.sendPort.send(JSON.encode(message));
  }

  void _sendToSelf(var message) {
    _me.send(JSON.encode(message));
  }

  void _flushBufferToEnqueuer() {
    while(_bufferMessagesToEnqueuer.isNotEmpty) {
      _sendToSelf(_bufferMessagesToEnqueuer.removeAt(0));
    }
  }

  void _flushBufferToDequeuer() {
    while(_bufferMessagesToDequeuer.isNotEmpty) {
      _sendToSelf(_bufferMessagesToDequeuer.removeAt(0));
    }
  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, _receivePort.sendPort);
  }

  Future<Isolate> _startDequeuerIsolate(List<String> args) {
    return Isolate.spawnUri(dequeueIsolate, args, _receivePort.sendPort);
  }

  _Dequeuer _getDequeuerByTopic(String topic) {
    return _dequeuers.firstWhere((dequeuer) => dequeuer.topic == topic, orElse:() => null);
  }

  List<_Dequeuer> _getDequeuersByIsolateSystemName(String systemName) {
    return _dequeuers.where((dequeuer) => dequeuer.isolateSystemName == systemName);
  }

  _Dequeuer _getDequeuerByIsolateSystemId(String id) {
    return _dequeuers.firstWhere((dequeuer) => dequeuer.isolateSystem._sockets.containsKey(id), orElse:() => null);
  }

  _IsolateSystem _getIsolateSystemByName(String systemName) {
    return _connectedSystems.firstWhere((isolateSystem) => isolateSystem.name == systemName, orElse:() => null);
  }

  void _removeSystemFromDequeuers(_IsolateSystem system) {
    _dequeuers.removeWhere((dequeuer) => dequeuer.isolateSystem.name == system.name);
  }

  _updateIsolateSystemInDequeuers(_IsolateSystem system) {
    for(_Dequeuer dequeuer in _getDequeuersByIsolateSystemName(system.name)) {
      dequeuer.system = system;
    }
  }

  _log(String text) {
    //print(text);
  }
}

/**
 * Start the Message Queuing System
 */
main(List<String> args) {
  String host = "127.0.0.1";
  String port = "61613";
  String username = Mqs.DEFAULT_LOGIN;
  String password = Mqs.DEFAULT_PASSWORD;
  String prefetchCount = "1";

  if(args is List && args.length >= 4) {
    host = args[0];
    port = args[1];
    username = args[2];
    password = args[3];
    if(args.length == 5) {
      prefetchCount = args[4];
    }
  }
  Mqs mqs = new Mqs(host:"127.0.0.1", port:61613, username:Mqs.DEFAULT_LOGIN, password: Mqs.DEFAULT_PASSWORD, prefetchCount:prefetchCount); //port for connection via STOMP (rabbitMQ)
}

class _IsolateSystem {
  String _name;
  // A map of uniqueId of system and Socket object
  Map<String, WebSocket> _sockets;

  String get name => _name;
  set name(String value) => _name = value;

  Map<String, WebSocket> get sockets => _sockets;
  set sockets(Map<String, WebSocket> value) => _sockets = value;

  _IsolateSystem(this._name, String isolateSystemId, WebSocket socket) {
    if(_sockets == null) {
      _sockets = new Map();
    }
    this._sockets[isolateSystemId] = socket;
  }
}

//multiple dequeuers can refer to same system
class _Dequeuer {
  String _topic;
  SendPort _sendPort;
  String _isolateSystemName;
  _IsolateSystem _isolateSystem;

  _Dequeuer(this._topic, this._isolateSystemName, this._isolateSystem);

  String get topic => _topic;
  set topic(String value) => _topic = value;

  SendPort get sendPort => _sendPort;
  set sendPort(SendPort value) => _sendPort = value;

  _IsolateSystem get isolateSystem => _isolateSystem;
  set system(_IsolateSystem value) => _isolateSystem = value;

  String get isolateSystemName => _isolateSystemName;
  set isolateSystemName(String value) => _isolateSystemName = value;
}
