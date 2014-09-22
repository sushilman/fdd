library isolatesystem.IsolateSystem;

import 'dart:async';
import 'dart:isolate';
import 'action/Action.dart';
import 'router/Random.dart';
import 'dart:math' as Math;
import 'dart:convert';


/**
 * Will be spawned/started by Activator?
 *
 * This can probably be merged with controller?
 */

/**
 * Controller will send a pull request
 * after which, a message is fetched using messageQueuingSystem
 * from appropriate queue and sent to the controller
 */
class IsolateSystem {
  ReceivePort receivePort;
  SendPort sendPort;
  SendPort self;

  Isolate controllerIsolate;

  int counter = 0;

  IsolateSystem(String workerUri, int workersCount, List<String> workersPaths, String routerUri) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;

    /**
     * These values may be in some configuration file or can be passed as a message/argument during initialization
     */
//    String routerUri = "router/Random.dart";
//    String workerUri = "../helloSystem/PrinterIsolate.dart";
//    int workersCount = 5;

    _spawnController(routerUri, workerUri, workersCount, JSON.encode(workersPaths));

    receivePort.listen((message) {
      _onReceive(message);
    });

    /**
     * Test code that sends message to isolate
     */
    int counter = 0;
//    new Timer.periodic(const Duration(milliseconds: 100), (t) {
//      sendPort.send('Print me: ${counter++}');
//      print ("Sending $counter");
//    });
  }

  _onReceive(message) {
    //print("IsolateSystem: $message");
    if(message is SendPort) {
      sendPort = message;
      //sendPort.send(Messages.createEvent(Action.SPAWN, {"router":"router/Random.dart", "count" : "5"}));
    } else if (message is List) {
      //print ("Event received : ${message[0]}");
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
    Isolate.spawnUri(Uri.parse('packages/isolatesystem/controller/Controller.dart'), [routerUri, workerUri, workersCount.toString(), workersPaths], receivePort.sendPort)
    .then((controller){
      controllerIsolate = controller;
    });
  }

  _pullMessage() {
    // TODO: pull message from appropriate queue from MessageQueuingSystem
    // something like messageQueuingSystem.send(message)
    // then send to sendPort of controller
    // sendPort.send(newMessage);
    //
    self.send("Simple message #${counter++}, ${new Math.Random().nextInt(99999)}");
  }

  _prepareResponse(var message) {
    var ResponseMessage = message[1];
    print("IsolateSystem: Enqueue this response : ${message[1]}");
  }
}
