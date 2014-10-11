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
main(List<String> args, SendPort sendPort) {
  print("Proxy Isolate: $args");
  Proxy proxy = new Proxy(args, sendPort);
}

/**
 * TODO:
 * Handle when the server connection is lost (or server is shutdown)
 * Refer to websocket client of SystemBootstrapper in activator package
 *
 * May be if a connection to one activator is lost for a long time, try some alternatives?
 * but how and where to get address?
 */
class Proxy extends Worker {
  SendPort self;

  WebSocket ws;
  Uri workerSourceUri;
  String workerPath;
  var extraArgs;
  /**
   * Need some error prevention here
   * if workerPath is not good websocket uri
   */
  Proxy(List<String> args, SendPort sendPort) : super.withoutReadyMessage(args, sendPort) {
    self = receivePort.sendPort;

    workerPath = args[0];
    workerSourceUri = args[1];
    extraArgs = args[2];

    print("Proxy: Connecting to webSocket...");
    WebSocket.connect(workerPath).then(_handleWebSocket).catchError(onError);
  }

  @override
  onReceive(var message) {
    //Serialize and delegate to webSocket
    //TODO: same id should be used for the isolate spawned by activator
    // i.e. id of proxy and remote isolate will be the same
    print("Proxy: Sending message -> $message");

    //'to':name can be included here, but not it's not significant
    ws.add(JSON.encode(MessageUtil.create(SenderType.PROXY, id, Action.NONE, {'message': message, 'replyTo': replyTo})));
  }

  void _handleWebSocket(WebSocket ws) {
    this.ws = ws;
    if(ws != null && ws.readyState == WebSocket.OPEN) {
      print("Proxy: WebSocket Connected !");
      // send initialization message
      // SPAWN Isolate on remote location
      var message = JSON.encode(MessageUtil.create(SenderType.PROXY, id, Action.SPAWN, [poolName, workerSourceUri.toString(), workerPath, extraArgs]));
      //print("Proxy: $message");
      ws.add(message);
    }
    ws.listen(_onData);
  }

  void _onData(String msg) {
    // Deserialize and send to itself first? router
    // print("Response from Activator: $msg");
    List<String> message = isJsonString(msg) ? JSON.decode(msg) : msg;

    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      String payload = MessageUtil.getPayload(message);

      switch(action) {
        case Action.CREATED:
          print("READY message sent");
          sendPort.send(MessageUtil.create(SenderType.PROXY, id, Action.CREATED, receivePort.sendPort));
          break;
        case Action.ERROR:
        //TODO: end isolate: close sendport, disconnect websocket
          kill();
          break;
        case Action.RESTARTING:
          sendPort.send(MessageUtil.create(SenderType.PROXY, id, Action.RESTARTING, null));
          receivePort.close();
          ws.close().then((value) {
            print("Proxy: WebSocket connection with activator is now closed.");
          });
          break;
        default:
          sendPort.send(message);
          break;
      }
    }
  }

  void onError(var message) {
    print('Not connected: $message');
  }

  @override
  void kill() {
    sendPort.send(MessageUtil.create(SenderType.PROXY, id, Action.KILLED,null));
    ws.close().then((value) {
      print("Proxy: WebSocket Disconnected.");
    });
    receivePort.close();
  }

  @override
  void restart() {
    ws.add(JSON.encode(MessageUtil.create(SenderType.PROXY, id, Action.RESTART, null)));
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
