import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import "Mqs.dart";
import "action/Action.dart";
import "message/MessageUtil.dart";

void main() {
  WebSocket.connect("ws://localhost:42043/mqs/isolateSystem").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData);
  new Timer.periodic (const Duration(seconds:5), (t) {
    String topic = "isolateSystem.helloPrinter";
    var message = MessageUtil.createDequeueMessage(topic);
    socket.add(JSON.encode(message));
    print("\n\n\nRequest sent: ");
  });
}

_onData(var message) {
  print("Before decoding: $message");
  message = JSON.decode(message);
  print("Dequeued -> $message");
}

_onError() {

}
