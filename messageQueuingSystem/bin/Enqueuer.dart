import 'dart:isolate';
import 'dart:async';

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "package:isolatesystem/worker/Worker.dart";
import "Mqs.dart";


main(List<String> args, SendPort sendPort) {
  new Enqueuer(args, sendPort);
}

class Enqueuer extends Worker {
  StompClient client;
  SendPort replyPort;
  int maxMessageBuffer = 1;
  Map<String, String> bufferMailBox = new Map();

  Enqueuer(List<String> args, SendPort sendPort):super(args, sendPort) {
    String host = args[0];
    int port = args[1];
    String username = args[2];
    String password = args[3];
    connect(host, port:port, login:username, passcode:password).then(_handleStompClient).then((_) {
      print("Enqueuer Listening...");
    });
  }

  void onReceive(message) {
    if(message is SendPort) {
      print("Send port received !");
    } else {
      print("Enqueue $message in message_broker_system");
      _enqueueMessage(Mqs.TOPIC, message, headers:Mqs.HEADERS);
    }
  }

  _handleStompClient(StompClient stompclient) {
    //stompclient.subscribeString("id1", "/queue/test", _onData);
    client = stompclient;
  }
  //
  //_onData(Map<String, String> headers, String message) {
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

}