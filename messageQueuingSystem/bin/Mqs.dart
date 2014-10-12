library messageQueuingSystem.Mqs;

import 'dart:io';
import "dart:isolate";
import "dart:async";
import 'dart:convert';

import "WebSocketServer.dart";
import "enqueueIsolate.dart";
import "dequeueIsolate.dart";

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
 */

class Mqs {

  static const String DEQUEUE = "action.dequeue";
  static const String ENQUEUE = "action.enqueue";

  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;

  static const String DEFAULT_LOGIN = "fdd";
  static const String DEFAULT_PASSWORD = "pass";

  static const String EXTERNAL = "senderType.external";

  //static const String GUEST_LOGIN = "guest";
  //static const String GUEST_PASSWORD = "guest";

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

  Uri enqueueIsolate = Uri.parse("enqueueIsolate.dart");
  Uri dequeueIsolate = Uri.parse("dequeueIsolate.dart");

  WebSocketServer wss;

  String webSocketPath = "/mqs";
  String listeningPort = "42043";

  List<String> connectionArgs;

  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:DEFAULT_LOGIN, password:DEFAULT_PASSWORD}) {
    _subscribedTopics = new List();
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _dequeuers = new List();
//    receivePortEnqueue.listen(_onReceiveFromEnqueueIsolate);
//
//    receivePortDequeue = new ReceivePort();
//    receivePortDequeue.listen(_onReceiveFromDequeueIsolate);

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
        case ENQUEUER:
          _handleEnqueuerMessages(message['message']);
          break;
        case Dequeuer.DEQUEUER:
          _handleDequeuerMessages(message);
          break;
        case EXTERNAL:
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

  _onData(WebSocket socket, var msg) {
    var message = JSON.decode(msg);
    _me.send({'senderType':EXTERNAL, 'message':message});
  }

  _onDisconnect(WebSocket socket) {

  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, _receivePort.sendPort);
  }

  _startDequeuerIsolate(List<String> args) {
    Isolate.spawnUri(dequeueIsolate, args, _receivePort.sendPort);
  }

  _handleEnqueue(String topic, String payload, String fullMessage) {
    Map msg = {'topic':topic, 'action':Mqs.ENQUEUE, 'message': payload};
    if(!_subscribedTopics.contains(topic)) {
      _subscribedTopics.add(topic);
      // If the topic is new, start a new dequeuer for that topic
      _Dequeuer _dequeuer = new _Dequeuer(topic);
      _dequeuers.add(_dequeuer);
      List temp  = new List();
      temp.addAll(connectionArgs);
      temp.add(topic);

      print("TEMP -> $temp");
      _startDequeuerIsolate(temp);
    }
    if(_enqueuerSendPort == null) {
      _me.send(fullMessage);
    } else {
      _enqueuerSendPort.send(msg);
    }
  }

  String _handleDequeue(String topic, var fullMessage) {
    if(!_subscribedTopics.contains(topic)) {
      _subscribedTopics.add(topic);
      // If the topic is new, start a new dequeuer for that topic
      _Dequeuer _dequeuer = new _Dequeuer(topic);
      _dequeuers.add(_dequeuer);
      List temp  = new List();
      temp.addAll(connectionArgs);
      temp.add(topic);

      print("TEMP -> $temp");
      _startDequeuerIsolate(temp);
    }

    _Dequeuer dequeuer = _getDequeuerByTopic(topic);
    if(dequeuer != null && dequeuer.sendPort != null) {
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
}

/**
 * Start the Message Queuing System
 */
main() {
  Mqs mqs = new Mqs(host:"127.0.0.1", port:61613);
  int counter = 0;
  String topic = "test1";
  String topic2 = "test2";
//
//  new Timer.periodic(const Duration(seconds:1), (t) {
////    String tempTopic = topic;
////    if(counter % 3 == 0) {
////      tempTopic = topic2;
////    }
//    var payload = {'replyTo':"", 'message':"Enqueue this message"};
//    Map message = {'senderId':"isolateSystem", 'action':"action.enqueue", 'payload':payload};
//    _me.send({'senderType':Mqs.EXTERNAL, 'message':message});
//  });
//
//  new Timer.periodic(const Duration(seconds:5), (t) {
////    String tempTopic2 = topic;
////    if(counter % 2 == 0) {
////      tempTopic2 = topic2;
////    }
//    Map message = {'senderId':"isolateSystem", 'action':"action.dequeue"};
//    _me.send({'senderType':Mqs.EXTERNAL, 'message':message});
//  });

}

class _IsolateSystem {
  String _id;
  WebSocket _socket;

  String get id => _id;
  set id(String value) => _id = value;

  WebSocket get socket => _socket;
  set socket(WebSocket value) => _socket = value;

}

class _Dequeuer {
  String _topic;
  SendPort _sendPort;
  _IsolateSystem _system;

  _Dequeuer(this._topic);

  String get topic => _topic;
  set topic(String value) => _topic = value;

  SendPort get sendPort => _sendPort;
  set sendPort(SendPort value) => _sendPort = value;

  _IsolateSystem get system => _system;
  set system(_IsolateSystem value) => _system = value;


}
