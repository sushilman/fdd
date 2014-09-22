library isolatesystem.worker.Proxy;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import '../action/Action.dart';
import 'Worker.dart';

/**
 * Receives message from router and sends it via webSocket to respective activator
 */

main(List<String> args, SendPort sendPort) {
  Proxy proxy = new Proxy(args[0], args[1]);

}

class Proxy implements Worker {
  ReceivePort receivePort;
  SendPort sendPortOfRouter;
  String id;

  WebSocket ws;
  String host;
  String address;

  //For testing purpose
  static const String DEFAULT_ADDRESS = "/activator";
  static const String DEFAULT_HOST = "ws://localhost:42042";

  Proxy(String this.host, String this.address) {
    print("Connecting to webSocket...");
    WebSocket.connect(host + address).then(handleWebSocket).catchError(onError);
  }

  @override
  onReceive(var message) {
    // Serialize and delegate to webSocket
    //TODO: assuming same id is used for the isolate spawned by activator
    ws.add(JSON.encode([id, message]));
  }

  void handleWebSocket(WebSocket ws) {
    this.ws = ws;
    if(ws != null && ws.readyState == WebSocket.OPEN) {
      // send initialization message
      // i.e. spawn isolate
    }
    ws.listen(onData);
  }

  void onData(String message) {
    // Deserialize and send to router

    print("Response from Activator: $message");
    message = isJsonString(message) ? JSON.decode(message) : message;
    sendPortOfRouter.send(message);
  }

  void onError(var message) {
    print('Not connected: $message');
  }

  bool isJsonString(var string) {
    try {
      JSON.decode(string);
      return true;
    } catch (exception) {
      return false;
    }
  }
}
