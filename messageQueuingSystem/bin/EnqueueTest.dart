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
  socket.listen(_onData, onError:_onError, onDone:_onDisconnect);
  int counter = 0;
  String replyTo = "isolateSystem.helloPrinter";
  String targetQueue = "isolateSystem.helloPrinter5";
  new Timer.periodic(const Duration(microseconds:1),(t) {
    Map payload = {
        'sender': 'isolateSystem/helloPrinter', 'message': 'My Message #${counter++}', 'replyTo':replyTo
    };

    var enqueueMessage = MessageUtil.createEnqueueMessage(targetQueue, payload);
    print(enqueueMessage);
    socket.add(JSON.encode(enqueueMessage));
  });

}

_onData(var message) {

}

_onError() {
  print("Error on Server, reconnect !");
}

_onDisconnect() {
  print("Disconnected, try re-establish the connection");
}
