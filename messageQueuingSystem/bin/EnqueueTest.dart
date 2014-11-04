import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "message/MessageUtil.dart";

String uniqueId = "1234-dfda-23da-343c-aeb3";

void main() {
  WebSocket.connect("ws://localhost:42043/mqs/isolateSystem/$uniqueId").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData, onError:_onError, onDone:_onDisconnect);
  int counter = 0;
  String poolName = "isolateSystem.helloPrinter";
  String targetQueue = "isolateSystem.helloPrinter5";
  new Timer.periodic(const Duration(microseconds:1),(t) {
    Map payload = {
        'sender': poolName, 'message': 'My Message #${counter++}', 'replyTo':poolName
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
