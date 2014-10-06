import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";

StompClient client;
SendPort replyPort;
int maxMessageBuffer = 1;
Map<String, String> bufferMailBox = new Map();

/**
 * TODO: There are some ugly hacks that needs to be taken care of !
 *
 *
 * Each Enqueuing and Dequeuing isolate for each TOPIC? or one for all
 * if One for all, then Dequeuer will have to subscribe to each topic that is not yet subscribed
 */

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort);
  replyPort = sendport;

  String host = args[0];
  int port = args[1];
  String username = args[2];
  String password = args[3];

  connect(host, port:port, login:username, passcode:password).then(_handleStompClient);

  print("Dequeuer Listening...");

  receivePort.listen((msg) {
    _onData(msg);
  });
}

_handleStompClient(StompClient stompclient) {
  client = stompclient;
  _subscribeMessage(Mqs.TOPIC);
}

/**
 * Receives message from rabbitmq and keeps in memory buffer but won't be ack'ed yet
 */
_onReceive(Map<String, String> headers, String message) {
  print("Message in buffer: $message");
  bufferMailBox[headers["ack"]] = message;
}

/**
 * Ack after dequeue() is received
 */
_flushBuffer(Map<String, String> buffer) {
  buffer.forEach((key, value){
    replyPort.send(value);
    client.ack(key);
  });
  buffer.clear();
}

_subscribeMessage(String topic) {
  try {
    client.subscribeString("myId", topic, _onReceive, ack:CLIENT_INDIVIDUAL);
    print("Subscribed to myId");
  } catch(e) {
    // already subscribed
  }
}

void _onData(message) {
  if(message is SendPort) {
    print("Send port received !");
  //else if message is "dequeue" (from topic?)
  } else {
    //print("Dequeue a message from message_broker_system");
    _flushBuffer(bufferMailBox);
  }
}
