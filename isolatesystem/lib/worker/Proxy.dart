library isolatesystem.worker.Proxy;

import 'dart:io';
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
proxyWorker(Map args) {
  new Proxy(args);
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
  Proxy(Map args) : super.internal(args) {
    workerPath = args['workerPath'];
    workerSourceUri = args['workerSourceUri'];
    extraArgs = args['extraArgs'];

    _log("Proxy: Connecting to webSocket...");
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
    _log("PROXY: $message");
    if(message is Map) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      String payload = MessageUtil.getPayload(message);

      switch(action) {
        case Action.CREATED:
          _log("CREATED message sent, my id = $id");
          sendPort.send([SenderType.PROXY, id, Action.CREATED, workerReceivePort.sendPort]);
          break;
        case Action.ERROR:
          beforeKill();
          break;
        case Action.RESTARTING:
          _sendToRouter(MessageUtil.create(SenderType.PROXY, id, Action.RESTARTING, null));
          workerReceivePort.close();
          webSocket.close().then((value) {
            _log("Proxy: WebSocket connection with activator is now closed.");
          });
          break;
        default:
          _sendToRouter(message);
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
    _sendToRouter(MessageUtil.create(SenderType.PROXY, id, Action.ERROR, null));
    //_initWebSocket();
  }

  void _sendToRouter (var message) {
    sendPort.send(JSON.encode(message));
  }

  @override
  Future beforeKill() {
    return new Future(() {
      _sendToRouter(MessageUtil.create(SenderType.PROXY, id, Action.KILLED,null));
      webSocket.close().then((value) {
        _log("Proxy: WebSocket Disconnected.");
      });
      workerReceivePort.close();
    });
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
    print(text);
  }
}
