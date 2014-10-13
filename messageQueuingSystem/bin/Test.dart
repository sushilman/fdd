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
  WebSocket.connect("ws://localhost:42043/mqs/isolateSystem").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData);
  int counter = 0;
  new Timer.periodic (const Duration(seconds:1), (t) {
    String msg = "Enqueue this message ${counter++}";
    var payload = {'message':msg};
    Map message = {'senderId':"helloPrinter", 'action':Mqs.ENQUEUE, 'payload':payload};
    socket.add(JSON.encode(message));
  });
}

_onData(var message) {
  JSON.decode(message);
  print("Dequeued -> $message");
}

_onError() {

}
