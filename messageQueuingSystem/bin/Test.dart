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
  WebSocket.connect("ws://localhost:42043/mqs/anySystem").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData, onError:_onError, onDone:_onDisconnect);
  int counter = 0;
  new Timer.periodic (const Duration(seconds:0.01), (t) {
    String msg = "My message #${counter++}";
    Map message = {'targetIsolateSystemId':'isolateSystem', 'isolateName':"helloPrinter", 'action':Mqs.ENQUEUE, 'payload':msg};
    socket.add(JSON.encode(message));
  });
}

_onData(var message) {
  JSON.decode(message);
  print("Dequeued -> $message");
}

_onError() {
  print("Error on Server, reconnect !");
}

_onDisconnect() {
  print("Disconnected, try re-establish the connection");
}
