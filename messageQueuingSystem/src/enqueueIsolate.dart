import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";

StompClient client;

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort);

  String host = args[0];
  int port = args[1];
  String username = args[2];
  String password = args[3];

  connect(host, port:port, login:username, passcode:password).then(_handleStompClient);

  print("Enqueuer Listening...");

  receivePort.listen((msg) {
    _onData(msg, sendport);
  });
}

_handleStompClient(StompClient stompclient) {
  //stompclient.subscribeString("id1", "/queue/test", _onReceive);
  client = stompclient;
}
//
//_onReceive(Map<String, String> headers, String message) {
//  print("Receive $message, $headers");
//}

/// returns true if successfully enqueued
bool _enqueueMessage(String topic, String message, {Map<String, String> headers}) {
  if(client != null) {
    client.sendString(topic, message, headers:headers);
    print("Message sent successfully from enqueuer to rabbitmq via stomp...");
    return true;
  }
  return false;
}

void _onData(message, sendport) {
  if(message is SendPort) {
    print("Send port received !");
  } else {
    print("Enqueue $message in message_broker_system");
    _enqueueMessage(Mqs.TOPIC, message, headers:Mqs.HEADERS);
  }
}