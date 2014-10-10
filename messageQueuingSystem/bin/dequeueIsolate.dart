import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";

StompClient client;
SendPort replyPort;
SendPort me;
int maxMessageBuffer = 1;

Map<String, String> bufferMailBox = new Map();

Map<String, bool> subscribedTopics = new Map();
const String DEQUEUED = "action.dequeued";

/**
 * TODO: There are some ugly hacks that needs to be taken care of !
 *
 *
 * Each Enqueuing and Dequeuing isolate for each TOPIC?
 * if One for all, then Dequeuer will have to subscribe to each topic that is not yet subscribed
 *
 * Each enqueuer/dequeuer for each topic would be better
 * because of ack problem, ack will ack only one message from one of the queue, and buffer will have old message
 * so rabbitmq, will not send another message unless old one is delivered and ack'ed
 *
 * Each isolate for each queue is good solution
 */

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  me = receivePort.sendPort;
  sendport.send(me);
  replyPort = sendport;

  String host = args[0];
  int port = args[1];
  String username = args[2];
  String password = args[3];

  connect(host, port:port, login:username, passcode:password).then(_handleStompClient);

  print("Dequeuer Listening...");

  receivePort.listen((msg) {
    _onReceive(msg);
  });
}

_handleStompClient(StompClient stompclient) {
  client = stompclient;
  //_subscribeMessage(Mqs.TOPIC);
}

/**
 * Receives message from rabbitmq and keeps in memory buffer but won't be ack'ed yet
 *
 * how to know which topic? headers?
 */
_onData(Map<String, String> headers, String message) {
  print("Message in buffer: $message, HEADERS: $headers");
  String key = headers["ack"];
  //send message to self to add it to buffer
  me.send({'key':key, 'topic':headers['destination'], 'action':DEQUEUED, 'message':message});

  //bufferMailBox[headers["ack"]] = message;
}

/**
 * Ack after dequeue() is received
 */
_flushBuffer() {
  bufferMailBox.forEach((key, value){
    replyPort.send(value);
    client.ack(key);
  });
  bufferMailBox.clear();
}

_subscribeMessage(String topic) {
  try {
    client.subscribeString("id_$topic", "$topic", _onData, ack:CLIENT_INDIVIDUAL);
    subscribedTopics[topic] = true;
    print("Subscribed to myId");
  } catch(e) {
    print("Already Subscribed");
    //Already subscribed
  }
}

void _onReceive(msg) {
  print("Dequeue Isolate : $msg");
  if(msg is SendPort) {
    print("Send port received !");
  //else if message is "dequeue" (from topic?)
  } else if (msg is Map) {
    String action = msg['action'];
    String topic = msg['topic'];
    switch(action) {
      case Mqs.DEQUEUE:
        // if already subscribed, flush buffer
        if(subscribedTopics.containsKey(topic)) {
          _flushBuffer();
        } else {
          _subscribeMessage(topic);
        }
        break;
      case DEQUEUED:
        bufferMailBox[msg['key']] = msg['message'];
        if(subscribedTopics[topic]) {
          _flushBuffer();
          subscribedTopics[topic] = false;
        }
        break;
      default:
        print("Unknown message -> $msg");
    }
  }
}
