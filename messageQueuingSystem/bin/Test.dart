import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "Mqs.dart";

class Test {
  Test() {
  }
}

void main() {
  WebSocket.connect("ws://localhost:42043/mqs").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData);
  int counter = 3;
  new Timer.periodic (const Duration(seconds:1), (t) {
    String msg = "Enqueue this message ${counter++}";
    var payload = {'replyTo':"isolateSystem.helloPrinter3", 'message':msg};
    Map message = {'senderId':"isolateSystem.helloPrinter3", 'action':Mqs.ENQUEUE, 'payload':payload};
    //socket.add(JSON.encode(message));
  });

  Map dequeueMessage = {'senderId':"isolateSystem.helloPrinter", 'action':Mqs.DEQUEUE};
  socket.add(JSON.encode(dequeueMessage));
}

_onData(var message) {
  JSON.decode(message);
  print("Dequeued -> $message");
}

_onError() {

}
