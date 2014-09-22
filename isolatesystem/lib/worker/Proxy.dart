library isolatesystem.worker.Proxy;

import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import '../action/Action.dart';
import 'Worker.dart';

import 'dart:io' show sleep;
/**
 * Receives message from router and sends it via webSocket to respective activator
 */

main(List<String> args, SendPort sendPort) {
  print("Proxy Isolate: $args");
  Proxy proxy = new Proxy(args, sendPort);
}

/**
 * TODO:
 * One idea is not to reply with sendPort immediately (override default behavior of Worker class)
 * send the sendPort only after webSocket connection has been established
 * or the remote isolate has been spawned
 */
class Proxy extends Worker {
  SendPort self;

  WebSocket ws;
  Uri workerSourceUri;

  /**
   * Need some error prevention here
   * if workerPath is not good websocket uri
   */
  Proxy(List<String> args, SendPort sendPort) : super(args, sendPort) {
    self = receivePort.sendPort;

    String workerPath = args[1];
    workerSourceUri = args[2];

    print("Proxy: Connecting to webSocket...");
    WebSocket.connect(workerPath).then(handleWebSocket).catchError(onError);
  }

  @override
  onReceive(var message) {
    //Serialize and delegate to webSocket
    //TODO: assuming same id is used for the isolate spawned by activator
    print("Proxy: Trying to send $message");
    ws.add(JSON.encode([id, message]));
  }

  void handleWebSocket(WebSocket ws) {
    this.ws = ws;
    if(ws != null && ws.readyState == WebSocket.OPEN) {
      print("Proxy: WebSocket Connected !");
      sendPortOfRouter.send([id, receivePort.sendPort]);
      // send initialization message
      // SPAWN Isolate on remote location
      var message = JSON.encode([Action.SPAWN, workerSourceUri.toString(), id]);
      print("Proxy: $message");
      ws.add(message);
    }

    ws.listen(onData);
    // send message to self and invoke this
    // ws.add(JSON.encode([Action.SPAWN, workerUri, id]));
    // send spawn messages here?
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
