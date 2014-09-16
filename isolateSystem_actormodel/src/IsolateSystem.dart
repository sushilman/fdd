import 'dart:async';
import 'dart:isolate';
import 'messages/Messages.dart';
import 'router/Random.dart';
import 'dart:math' as Math;

/**
 * Controller will send a pull request
 * after which, a message is fetched using messageQueuingSystem
 * from appropriate queue and sent to the controller
 */
class IsolateSystem {
  ReceivePort receivePort;
  SendPort sendPort;
  Isolate controllerIsolate;

  IsolateSystem() {
    receivePort = new ReceivePort();

    /**
     * These values may be in some configuration file or can be passed as a message/argument during initialization
     */
    String routerUri = "../router/Random.dart";
    String workerUri = "../PrinterIsolate.dart";
    int workersCount = 5;

    _spawnController(routerUri, workerUri, workersCount);

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
    print("IsolateSystem: $message");
    if(message is SendPort) {
      sendPort = message;
      //sendPort.send(Messages.createEvent(Action.SPAWN, {"router":"router/Random.dart", "count" : "5"}));
    } else if (message is Event) {
      print ("Event received : ${message.action} -> ${message.message}}");
      switch(message.action) {
        case Action.PULL_MESSAGE:
          String newMessage = _pullMessage();
          sendPort.send(newMessage);
        break;
      }
    } else {
      print ("Unknown message: $message");
    }
  }

  _spawnController(String routerUri, String workerUri, int workersCount) {
    Isolate.spawnUri(Uri.parse('controller/Controller.dart'), [routerUri, workerUri, workersCount], receivePort.sendPort)
    .then((controller){
      controllerIsolate = controller;
    });
  }

  _pullMessage() {
    //TODO: pull message from appropriate queue from MessageQueuingSystem
    return "Simple message ${new Math.Random().nextInt(99999)}";
  }
}

main() {
  new IsolateSystem();
}