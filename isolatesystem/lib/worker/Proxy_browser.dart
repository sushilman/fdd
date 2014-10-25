library isolatesystem.worker.Proxy;

import 'dart:html' show WebSocket;
import 'dart:convert';
import 'dart:isolate';
import 'dart:async';

import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';

import 'Worker.dart';

/**
 * Receives message from router and sends it via webSocket to respective activator
 */
main(List<String> args, SendPort sendPort) {
  Proxy proxy = new Proxy(args, sendPort);
}

/**
 * TODO:
 * Handle when the server connection is lost (or server is shutdown)
 * Refer to websocket client of SystemBootstrapper in activator package
 *
 */
class Proxy extends Worker {
  WebSocket webSocket;
  Uri workerSourceUri;
  String workerPath;
  var extraArgs;
  /**
   * Need some error prevention here
   * if workerPath is not good websocket uri
   */
  Proxy(List<String> args, SendPort sendPort) : super.withoutReadyMessage(args, sendPort) {
    workerPath = args[0];
    workerSourceUri = args[1];
    extraArgs = args[2];

    print("Proxy: Connecting to webSocket...");
    _initWebSocket();
  }

  @override
  onReceive(var message) {
    //Serialize and delegate to webSocket
    // same id is used for the isolate spawned by activator
    // i.e. id of proxy and remote isolate will be the same
    _log("Proxy: Sending message -> $message");

    //'to':name can be included here, but not it's not significant
    webSocket.add(JSON.encode(MessageUtil.create(SenderType.PROXY, id, Action.NONE, {'message': message, 'replyTo': respondTo})));
  }

  void _initWebSocket() {
    WebSocket.connect(workerPath).then(_handleWebSocket).catchError(_onError);
  }

  void _handleWebSocket(WebSocket ws) {
    if(ws != null && ws.readyState == WebSocket.OPEN) {
      this.webSocket = ws;
      _log("Proxy: WebSocket Connected !");
      var message = JSON.encode(MessageUtil.create(SenderType.PROXY, id, Action.SPAWN, [this.me, workerSourceUri.toString(), workerPath, extraArgs]));
      webSocket.add(message);
    }
    webSocket.listen(_onData, onDone: _onDone);
  }

  void _onData(String msg) {
    // Deserialize and send to itself first? router
    // print("Response from Activator: $msg");
    var message = isJsonString(msg) ? JSON.decode(msg) : msg;

    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      String payload = MessageUtil.getPayload(message);

      switch(action) {
        case Action.CREATED:
          _log("READY message sent");
          sendPort.send(MessageUtil.create(SenderType.PROXY, id, Action.CREATED, receivePort.sendPort));
          break;
        case Action.ERROR:
          //TODO: end isolate: close sendPort, disconnect webSocket
          kill();
          break;
        case Action.RESTARTING:
          sendPort.send(MessageUtil.create(SenderType.PROXY, id, Action.RESTARTING, null));
          receivePort.close();
          webSocket.close().then((value) {
            _log("Proxy: WebSocket connection with activator is now closed.");
          });
          break;
        default:
          sendPort.send(message);
          break;
      }
    }
  }

  void _onError(var message) {
    _log("Could not connect, retrying...");
    new Timer(new Duration(seconds:3), () {
      _log ("Retrying...");
      _initWebSocket();
    });
  }

  void _onDone() {
    _log("Connection closed by server!");
    _log("Reconnecting...");
    _initWebSocket();
  }


  @override
  void kill() {
    sendPort.send(MessageUtil.create(SenderType.PROXY, id, Action.KILLED,null));
    webSocket.close().then((value) {
      _log("Proxy: WebSocket Disconnected.");
    });
    receivePort.close();
  }

  void restart() {
    webSocket.add(JSON.encode(MessageUtil.create(SenderType.PROXY, id, Action.RESTART, null)));
  }

  bool isJsonString(var string) {
    try {
      JSON.decode(string);
      return true;
    } catch (exception) {
      return false;
    }
  }

  void _log(String text) {
    //print(text);
  }
}
