library messageQueuingSystem.enqueueIsolate;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";

main(List<String> args, SendPort sendPort) {
  new Enqueuer(args, sendPort);
}

class Enqueuer {
  StompClient client;
  static const String ENQUEUER = "senderType.enqueuer";

  String host;
  int connectToPort;
  String username;
  String password;

  Enqueuer(List<String> args, SendPort sendPort) {
    print("Enqueuer Spawned!!!");
    ReceivePort receivePort = new ReceivePort();
    sendPort.send({
        'senderType':ENQUEUER, 'message': receivePort.sendPort
    });

    host = args[0];
    connectToPort = args[1];
    username = args[2];
    password = args[3];

    _initConnection();

    print("Enqueuer Listening...");
    receivePort.listen(_onReceive);
  }


  _handleStompClient(StompClient stompClient) {
    client = stompClient;
    print("Connected!");
  }

  _reconnect() {
    print("Reconnecting...");
    new Timer(new Duration(seconds:3), () {
      _initConnection();
    });
  }

  void _onDisconnect(StompClient client) {
    _reconnect();
  }

  void _onError([StompClient client, String message, String detail, Map<String, String> headers]) {
    _reconnect();
  }

  _initConnection() {
    connect(host, port:connectToPort, login:username, passcode:password, onError:_onError, onDisconnect:_onDisconnect).then(_handleStompClient, onError:_onError);
  }

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
    if (message is Map) {
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
}