import 'dart:isolate';
import 'dart:async';

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "package:isolatesystem/worker/Worker.dart";
import "Mqs.dart";



/**
 * TODO: There are some ugly hacks that needs to be taken care of !
 */

main(List<String> args, SendPort sendPort) {
  new Dequeuer(args, sendPort);
}

class Dequeuer extends Worker {
  StompClient client;
  SendPort replyPort;
  int maxMessageBuffer = 1;
  Map<String, String> bufferMailBox = new Map();

  Dequeuer(List<String> args, SendPort sendPort):super(args, sendPort) {
    String host = args[0];
    int port = args[1];
    String username = args[2];
    String password = args[3];
    connect(host, port:port, login:username, passcode:password).then(_handleStompClient).then((_){
      print("Dequeuer Listening...");
    });
  }

  void onReceive(message) {
    if(message is SendPort) {
      print("Send port received !");
      //else if message is "dequeue" (from topic?)
    } else {
      //print("Dequeue a message from message_broker_system");
      _flushBuffer(bufferMailBox);
    }
  }

  /**
   * Receives message from rabbitmq and keeps in memory buffer but won't be ack'ed yet
   */
  _onData(Map<String, String> headers, String message) {
    print("Message in buffer: $message");
    bufferMailBox[headers["ack"]] = message;
  }

  _handleStompClient(StompClient stompclient) {
    client = stompclient;
    _subscribeMessage(Mqs.TOPIC);
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

}
