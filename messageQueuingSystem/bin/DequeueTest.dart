import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "Mqs.dart";

void main() {
  WebSocket.connect("ws://localhost:42043/mqs/isolateSystem").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData);
  new Timer.periodic (const Duration(seconds:5), (t) {
    Map message = {'isolateName':"helloPrinter", 'action':Mqs.DEQUEUE};
    socket.add(JSON.encode(message));
    print("\n\n\nRequest sent: ");
  });
}

_onData(var message) {
  message = JSON.decode(message);
  print("Dequeued -> $message");
}

_onError() {

}
