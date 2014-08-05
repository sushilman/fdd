import 'dart:async';
import 'dart:io';

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
    f.then(handleWebSocket);
  }

  void handleWebSocket(WebSocket ws) {
    if (ws != null && ws.readyState == WebSocket.OPEN) {
      print("Sent: Echo test");
      ws.add("Echo test");
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