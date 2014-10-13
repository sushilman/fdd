import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "Mqs.dart";

void main() {
  WebSocket.connect("ws://localhost:42043/mqs").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData);
  new Timer.periodic (const Duration(seconds:5), (t) {
    Map message = {'senderId':"isolateSystem.helloPrinter", 'action':Mqs.DEQUEUE};
    socket.add(JSON.encode(message));
  });
}

_onData(var message) {
  JSON.decode(message);
  print("Dequeued -> $message");
}

_onError() {

}
