import 'dart:async';
import 'dart:io';
import 'dart:convert';

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
      //var message = ["SPAWN", "https://raw.githubusercontent.com/sushilman/fdd/master/isolateSystem_actormodel/src/PrinterIsolate.dart", "1"];
      var message = ["SPAWN","../../isolateSystem_actormodel/src/PrinterIsolate.dart",["1"]];
      //var message2 = ["SPAWN","http://localhost:8080/PrinterIsolate.dart",["2"]];
      //var message3 = ["SPAWN","http://localhost:8080/PrinterIsolate.dart",["3"]];

      ws.add(JSON.encode(message));
      //ws.add(JSON.encode(message2));
      //ws.add(JSON.encode(message3));

    }

    ws.listen((String e) {
      print("Response: $e");
      if(e is String) {
        if(e == "DONE") {
          var message4 = ["1","Print me ${counter++}"];
          ws.add(JSON.encode(message4));
          ws.add(JSON.encode(message4));
          ws.add(JSON.encode(message4));
          ws.add(JSON.encode(message4));
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