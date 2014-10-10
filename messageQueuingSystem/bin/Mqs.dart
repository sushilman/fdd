import 'dart:io';
import "dart:isolate";
import "dart:async";
import 'dart:convert';

import "WebSocketServer.dart";
/**
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
 *
 * Maintain list of subscribed topics,
 * spawn new isolate to listen on given topic if one doesnot exist yet
 */

class Mqs {

  static const String DEQUEUE = "action.dequeue";
  static const String ENQUEUE = "action.enqueue";

  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;
  static const String GUEST_LOGIN = "guest";
  static const String GUEST_PASSWORD = "guest";

  //TODO: persistent queue - "topic/name"?
  //static const String TOPIC = "/queue/testA";
  static const String TOPIC = "/queue";
  static Map<String, String> HEADERS = null;//{'delivery-mode':'2'};//{'reply-to' : '/queue/test'};

  List<_Dequeuer> dequeuers;

  ReceivePort receivePortEnqueue;
  ReceivePort receivePortDequeue;
  SendPort enqueueSendPort;
  SendPort dequeueSendPort;

  List<String> subscribedTopics;

  Uri enqueueIsolate = Uri.parse("enqueueIsolate.dart");
  Uri dequeueIsolate = Uri.parse("dequeueIsolate.dart");

  WebSocketServer wss;

  String webSocketPath = "/mqs";
  String listeningPort = "42043";


  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:GUEST_LOGIN, password:GUEST_PASSWORD}) {
    subscribedTopics = new List();
    receivePortEnqueue = new ReceivePort();
    receivePortEnqueue.listen(_onReceiveFromEnqueueIsolate);
    print("Starting up enqueuer and dequeuer...");
    List<String> args = [host, port, username, password];
    _startEnqueuerIsolate(args);

    receivePortDequeue = new ReceivePort();
    receivePortDequeue.listen(_onReceiveFromDequeueIsolate);
    _startDequeuerIsolate(args);

    wss = new WebSocketServer(int.parse(listeningPort), webSocketPath, _onConnect, _onData, _onDisconnect);
  }

  _onConnect(WebSocket socket) {

  }

  _onData(WebSocket socket, var msg) {
    //TODO: listen to pull requests
    var message = JSON.decode(msg);
    String senderId = message[0];
    String action = message[1];


    if(action == "PULL") {
      // TODO: find topic-queue using senderId
      // 1. query registry with given senderId

      // 2. onReceive from registry
      // -> From registry : queue-topic and isolate_system_location
      dequeueSendPort.send({'action':Mqs.DEQUEUE});
    }
  }

  _onDisconnect(WebSocket socket) {

  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, receivePortEnqueue.sendPort);
  }

  _startDequeuerIsolate(List<String> args) {
    Isolate.spawnUri(dequeueIsolate, args, receivePortDequeue.sendPort);
  }

  _onReceiveFromEnqueueIsolate(message) {
    if(enqueueSendPort == null) {
      enqueueSendPort = message;
      print("Sendport to enq isolate $message" + enqueueSendPort.hashCode.toString());
    } else {
      print ("Received response from isolate: $message");
    }
    print ("Enqueue Response : $message");
  }

  _onReceiveFromDequeueIsolate(message) {
    if(dequeueSendPort == null) {
      dequeueSendPort = message;
      print("Sendport to deq isolate $message" + dequeueSendPort.hashCode.toString());
    } else {
      print (" ## Received response from dequeue isolate: $message");
    }
  }

  enqueue(String topic, String message) {
    Map msg = {'topic':topic, 'action':Mqs.ENQUEUE, 'message': message};
    enqueueSendPort.send(msg);
  }

  /**
   * Will be asynchronous
   */
  String dequeue(String topic) {
    dequeueSendPort.send({'action':Mqs.DEQUEUE, 'topic':'${Mqs.TOPIC}/$topic'});
  }

  _getDequeuerByTopic(String topic) {
    for(final dequeuer in dequeuers) {
      if(topic == dequeuer.topic) {
        return dequeuer;
      }
    }

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

//  new Timer.periodic(const Duration(seconds:0.1), (t) {
//    String tempTopic = topic;
//    if(counter % 3 == 0) {
//      tempTopic = topic2;
//    }
//    mqs.enqueue(tempTopic, "Message ${counter++}");
//  });
  new Timer.periodic(const Duration(seconds:5), (t) {
//    String tempTopic2 = topic;
//    if(counter % 2 == 0) {
//      tempTopic2 = topic2;
//    }
    mqs.dequeue(tempTopic2);
  });

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
  String _sendPort;

  _Dequeuer(this._topic);

  String get topic => _topic;
  set topic(String value) => _topic = value;

  String get sendPort => _sendPort;
  set sendPort(String value) => _sendPort = value;
}
