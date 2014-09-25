library isolatesystem.IsolateSystem;

import 'dart:async';
import 'dart:isolate';
import 'action/Action.dart';
import 'router/Random.dart';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' show dirname;


/**
 * This can probably be merged with controller?
 * Or is it better to separate?
 */

/**
 * Controller sends a pull request
 * after which, a message is fetched using messageQueuingSystem
 * from appropriate queue and sent to the controller
 */
class IsolateSystem {
  ReceivePort receivePort;
  SendPort sendPort;
  SendPort self;

  Isolate controllerIsolate;
  Isolate fileMonitorIsolate;
  bool hotDeployment = false;

  String workerUri;

  int counter = 0;

  IsolateSystem(String this.workerUri, int workersCount, List<String> workersPaths, String routerUri, {hotDeployment:false}) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;

    _spawnController(routerUri, workerUri, workersCount, JSON.encode(workersPaths));

    if(hotDeployment) {
      _spawnFileMonitor();
    }

    receivePort.listen((message) {
      _onReceive(message);
    });
  }

  _onReceive(message) {
    //print("IsolateSystem: $message");
    if(message is SendPort) {
      sendPort = message;
    } else if (message is List) {
      switch(message[0]) {
        case Action.PULL_MESSAGE:
          _pullMessage();
          break;
        case Action.DONE:
          if(message.length > 1) {
            _prepareResponse(message);
          }
          break;
        default:
          print("IsolateSystem: Unknown Action: ${message[0]}");
          break;
      }
    } else if (message is String) {
      sendPort.send(message);
    } else {
      print ("IsolateSystem: Unknown message: $message");
    }
  }

  _spawnController(String routerUri, String workerUri, int workersCount, String workersPaths) {
    String curDir = dirname(Platform.script.toString());
    String controllerUri = curDir + "/packages/isolatesystem/controller/Controller.dart";
    Isolate.spawnUri(Uri.parse(controllerUri), [routerUri, workerUri, workersCount.toString(), workersPaths], receivePort.sendPort)
    .then((controller){
      controllerIsolate = controller;
    });
  }

  _spawnFileMonitor() {
    String curDir = dirname(Platform.script.toString());
    Uri fileMonitorUri = Uri.parse(curDir + "/packages/isolatesystem/src/FileMonitor.dart");
    Isolate.spawnUri(fileMonitorUri, ["fileMonitor", workerUri],receivePort.sendPort).then((monitor) {
      fileMonitorIsolate = monitor;
    });
  }

  /**
   * Pulls message from MessageQueuingSystem over websocket connection
   */
  _pullMessage() {
    // TODO: pull message from appropriate queue from MessageQueuingSystem
    // something like messageQueuingSystem.send(message)
    // then send to sendPort of controller
    // sendPort.send(newMessage);
    //
    self.send("Simple message #${counter++}");
  }

  _prepareResponse(var message) {
    var ResponseMessage = message[1];
    print("IsolateSystem: Enqueue this response : ${message[1]}");
  }
}
