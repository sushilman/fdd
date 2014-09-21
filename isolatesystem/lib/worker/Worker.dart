library isolatesystem.worker.Worker;

import 'dart:isolate';
import 'dart:async';
import '../messages/Messages.dart';

abstract class Worker {
  ReceivePort receivePort;
  SendPort sendPortOfRouter;
  int id;

  Worker(List<String> args, this.sendPortOfRouter) {
    id = args[0];
    receivePort = new ReceivePort();
    sendPortOfRouter.send([id, receivePort.sendPort]);

    //sendPortOfRouter.send(receivePort.sendPort);
    receivePort.listen((var message) {
      _onReceive(message);
    });
  }

  _onReceive(var message) {
    print("Worker: $message");
    // do something and pass it on
    onReceive(message);
    sendPortOfRouter.send(Messages.createEvent(Action.DONE, null));
  }

  /**
   * onReceive can be made to return Future
   * So that only after onReceive is completed, DONE message is sent to router
   *
   * will this make it possible to implement Future in onReceive?
   */
  Future onReceive(var message);

}
