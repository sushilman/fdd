library isolatesystem.worker.Worker;

import 'dart:isolate';
import 'dart:async';
import '../action/Action.dart';

abstract class Worker {
  ReceivePort receivePort;
  SendPort sendPort;
  String id;

  Worker(List<String> args, this.sendPort) {
    id = args[0];
    receivePort = new ReceivePort();
    //sendPortOfRouter.send([id, receivePort.sendPort]);
    receivePort.listen((var message) {
      _onReceive(message);
    });
  }

  _onReceive(var message) {
    print("Worker $id: $message");
    // do something and pass it on
    if(message is List) {
      switch(message[0]) {
        case Action.KILL:
          kill();
          break;
        case Action.RESTART:
          restart();
          break;
      }

    } else {
      onReceive(message);
    }
    /**
     * Enabling DONE here creates issues with Proxy Isolate
     * Because, proxy isolate further via websocket spawns another isolate which is also a child of Worker
     * Thus DONE message ends up being sent twice
     */
    //sendPortOfRouter.send([Action.DONE, "My message here"]);
  }

  /**
   * onReceive can be made to return Future
   * So that only after onReceive is completed, DONE message is sent to router
   *
   * will this make it possible to include async calls in onReceive?
   */
  onReceive(var message);

  done([var message]) {
    message != null ? sendPort.send([Action.DONE, message]): sendPort.send([Action.DONE]);
  }

  void kill() {
    sendPort.send([Action.KILLED, id]);
    receivePort.close();
  }

  void restart() {
    sendPort.send([Action.RESTARTING, id]);
    receivePort.close();
  }
}
