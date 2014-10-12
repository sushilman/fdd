library messageQueuingSystem.enqueueIsolate;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";

StompClient client;
const String ENQUEUER = "senderType.enqueuer";

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send({'senderType':ENQUEUER, 'message': receivePort.sendPort});

  String host = args[0];
  int port = args[1];
  String username = args[2];
  String password = args[3];

  connect(host, port:port, login:username, passcode:password).then(_handleStompClient);

  print("Enqueuer Listening...");

  receivePort.listen(_onReceive);
}

_handleStompClient(StompClient stompclient) {
  client = stompclient;
}

//
//_onData(Map<String, String> headers, String message) {
//  print("Received $message, $headers");
//}

/// returns true if successfully enqueued
bool _enqueueMessage(String topic, String message, {Map<String, String> headers}) {
  if(client != null) {
    client.sendString(topic, JSON.encode(message), headers: headers);
    print("Message sent successfully from enqueuer to rabbitmq via stomp...");
    return true;
  }
  return false;
}

void _onReceive(var message) {
  print("Enqueue Isolate: $message");
  if(message is SendPort) {
    //print("Send port received !");
    //just in case if any child isolates are spawned
  } else if (message is Map) {
    String topic = Mqs.TOPIC + "/" + message['topic'];
    String action = message['action'];
    String msg = message['message'];

    switch (action) {
      case Mqs.ENQUEUE:
        print("Enqueue $message with headers: ${Mqs.HEADERS} to topic ${topic} in message_broker_system");
        _enqueueMessage(topic, message['message'], headers:Mqs.HEADERS);
        break;
    }
  }
}