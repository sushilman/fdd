library messageQueuingSystem.enqueueIsolate;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";
import "action/Action.dart";
import "message/MessageUtil.dart";

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

  List bufferMessages;

  Enqueuer(List<String> args, SendPort sendPort) {
    ReceivePort receivePort = new ReceivePort();
    sendPort.send([ENQUEUER, receivePort.sendPort]);

    host = args[0];
    connectToPort = args[1];
    username = args[2];
    password = args[3];

    bufferMessages = new List();

    _initConnection();
    receivePort.listen(_onReceive);
  }


  _handleStompClient(StompClient stompClient) {
    client = stompClient;
    _log("Enqueuer: Connected!");
  }

  _reconnect() {
    _log("Enqueuer: Reconnecting...");
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
      return true;
    }
    return false;
  }

  void _onReceive(var message) {
    _log("Enqueue Isolate: $message");
    if (MessageUtil.isValidMessage(message)) {
      if(message is String) {
        message = JSON.decode(message);
      }
      String topic = Mqs.TOPIC + "/" + MessageUtil.getTopic(message);
      String action = MessageUtil.getAction(message);
      String msg = message['payload'];

      switch (action) {
        case Action.ENQUEUE:
          _log("Enqueue $message with headers: ${Mqs.HEADERS} to topic ${topic} in message_broker_system");
          if(client != null) {
            _enqueueMessage(topic, message['payload'], headers:Mqs.HEADERS);
          } else {
            bufferMessages.add(message);
          }
          break;
      }
    }
  }

  _log(text) {
    //print(text);
  }
}