import 'dart:async';
import 'dart:isolate';
import 'messages/Messages.dart';
import 'router/Random.dart';

class IsolateSystem {
  ReceivePort receivePort;
  SendPort sendPort;

  IsolateSystem() {
    receivePort = new ReceivePort();
    Future<Isolate> controllerIsolate = Isolate.spawnUri(Uri.parse('controller/Controller.dart'), null, receivePort.sendPort);
    controllerIsolate.then((controller){
      controller.controlPort;
    });

    receivePort.listen((message) {
      _onReceive(message);
    });
  }

  _onReceive(message) {
    if(message is SendPort) {
      sendPort = message;
      sendPort.send(Messages.createEvent(Action.SPAWN, {"router":"router/Random.dart", "count" : "5"}));
    } else if (message is Event) {
      print ("Message received : ${message.message}");
    } else {
      print ("Unknown message: $message");
    }
  }
}

main() {
  new IsolateSystem();
}