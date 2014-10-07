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
 */

class Mqs {

  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;
  static const String GUEST_LOGIN = "guest";
  static const String GUEST_PASSWORD = "guest";

  static const String TOPIC = "/queue/test";
  static Map<String, String> HEADERS = null;//{'reply-to' : '/queue/test'};

  ReceivePort receivePortEnqueue;
  ReceivePort receivePortDequeue;
  SendPort enqueueSendPort;
  SendPort dequeueSendPort;

  Uri enqueueIsolate = Uri.parse("enqueueIsolate.dart");
  Uri dequeueIsolate = Uri.parse("dequeueIsolate.dart");

  WebSocketServer wss;

  String webSocketPath = "/mqs";
  String listeningPort = "42043";


  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:GUEST_LOGIN, password:GUEST_PASSWORD}) {
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
      print ("Received response from dequeue isolate: $message");
    }
    print ("Dequeued : $message");
  }

  enqueue(String message) {
    enqueueSendPort.send(message);
  }

  /**
   * Will be asynchronous
   */
  String dequeue() {
    dequeueSendPort.send("Dequeue a message");
  }
}

/**
 * Start the Message Queuing System
 */
main() {
  Mqs mqs = new Mqs(host:"127.0.0.1", port:61613);
  int counter = 0;
  new Timer.periodic(const Duration(seconds:0.1), (t) {
    mqs.enqueue("Message ${counter++}");
  });
  new Timer.periodic(const Duration(seconds:0.1), (t) {
    mqs.dequeue();
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