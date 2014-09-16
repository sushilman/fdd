import 'dart:async';
import 'dart:isolate';
import 'messages/Messages.dart';
import 'router/Random.dart';

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
    new Timer.periodic(const Duration(seconds: 2), (t) {
      sendPort.send('Print me: ${counter++}');
    });
  }

  _onReceive(message) {
    if(message is SendPort) {
      sendPort = message;
      //sendPort.send(Messages.createEvent(Action.SPAWN, {"router":"router/Random.dart", "count" : "5"}));
    } else if (message is Event) {
      print ("Message received : ${message.message}");
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
}

main() {
  new IsolateSystem();
}