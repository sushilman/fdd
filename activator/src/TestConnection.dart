import 'dart:async';
import 'dart:io';
import 'dart:convert';

/**
 * This nature should be incorporated in router
 */
class TestConnection {

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
      print("Sent: Echo test");
      //var message = ["SPAWN", "https://raw.githubusercontent.com/sushilman/fdd/master/isolateSystem_actormodel/src/PrinterIsolate.dart", "1"];
      var message = ["SPAWN","http://localhost:8080/PrinterIsolate.dart","1"];
      ws.add(JSON.encode(message));
    }

    ws.listen((String e) {
      print("Response: $e");
    });

  }

  void onError() {
    print('Not connected');
  }
}

void main() {
  new TestConnection();
}