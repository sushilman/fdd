library isolatesystem.controller.Controller;

import 'dart:isolate';
import 'dart:async';
import '../action/Action.dart';
import '../IsolateSystem.dart';

/**
 * Controller
 * needs many sendports -> list of all the routers it has spawned
 *
 * Should keep track of free isolates (with the help of router)
 * and send pull request to IsolateSystem
 */
main(List<String> args, SendPort sendPort) {
  Controller controller = new Controller(args, sendPort);
}

class Controller {
  ReceivePort receivePort;
  SendPort sendPortOfIsolateSystem;
  SendPort self;
  int workersCount;
  /**
   * Send port the router this controller has spawned
   */
  SendPort routerSendPort;

  //TODO: check proposal -> should be single router per isolate system
  Uri routerUri;
  Isolate routerIsolate;

  Controller(List<String> args, this.sendPortOfIsolateSystem) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;
    sendPortOfIsolateSystem.send(receivePort.sendPort);

    Uri routerUri = Uri.parse(args[0]);
    String workerUri = args[1];
    workersCount = int.parse(args[2]);

    receivePort.listen((message) {
      _onReceive(message);
    });

    _spawnRouter(receivePort, routerUri, workerUri, workersCount);
  }

  _onReceive(var message) {
    //print("Controller: $message");
    if(message is SendPort) {
      routerSendPort = message;
    } else if (message is List) {
      switch(message[0]) {
        case Action.SPAWN:
          //Do Nothing
          break;
        case Action.READY:
          for (int i = 0; i < workersCount; i++) {
            sendPortOfIsolateSystem.send([Action.PULL_MESSAGE]);
          }
          break;
        case Action.DONE:
          // The result message? along with DONE action
          // to be en-queued in MQS
          if(message.length > 1) {
            // may be some additional information of
            // the isolate and/or the original sender?
            sendPortOfIsolateSystem.send(message);
          }

          sendPortOfIsolateSystem.send([Action.PULL_MESSAGE]);
          break;
        default:
          print ("Controller: Unknown Action ${message[0]}");
          break;
      }
    } else if (message is String) {
      // For now, just delegate message to the router
      routerSendPort.send(message);
    }
  }

  _spawnRouter(ReceivePort receivePort, Uri routerUri, String workerUri, int workersCount) {
    Isolate.spawnUri(routerUri, [workerUri, workersCount.toString()], receivePort.sendPort).then((isolate) {
      routerUri = routerUri;
      routerIsolate = isolate;
    });
  }
}