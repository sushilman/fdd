import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:isolatesystem/action/Action.dart';

/**
 * This nature should be implemented in router
 */
class TestConnection {

  int counter = 0;
  TestConnection() {
    initWebSocket("/activator");
  }

  void initWebSocket (String address) {
    bool reconnectScheduled = false;

    if(address.isEmpty) {
      address = "/activator";
    }

    print("Connecting to websocket");

    Future f = WebSocket.connect('ws://localhost:42042' + address);
    f.then(handleWebSocket).catchError(onError);
  }

  void handleWebSocket(WebSocket ws) {
    if (ws != null && ws.readyState == WebSocket.OPEN) {
      print("Sent: SPAWN command");
      var message = ["SPAWN","../helloSystem/PrinterIsolate.dart",["1"]];
      ws.add(JSON.encode(message));
    }

    ws.listen((String message) {
      print("Response: $message");
      if(message is List) {
        switch(message[0]) {
          case Action.DONE:
            var message4 = ["1","Print me ${counter++}"];
            ws.add(JSON.encode(message4));
            break;
        }
      }
    });

  }

  void onError() {
    print('Not connected');
  }
}

void main() {
  new TestConnection();
}