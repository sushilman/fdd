library isolatesystem.worker.Worker;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';

abstract class Worker {
  ReceivePort receivePort;
  SendPort sendPort;
  String id;

  Worker(List<String> args, this.sendPort) {
    id = args[0];
    receivePort = new ReceivePort();
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.READY, receivePort.sendPort));
    receivePort.listen((var message) {
      _onReceive(message);
    });
  }

  Worker.withoutReadyMessage(List<String> args, this.sendPort) {
    id = args[0];
    receivePort = new ReceivePort();
    receivePort.listen(_onReceive, onDone:_onDone, cancelOnError:false);
  }

  _onDone() {
    print("On done: Receive port closed");
  }

  _onReceive(var message) {
    print("Worker $id: $message");
    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);

      switch(action) {
        case Action.KILL:
          kill();
          break;
        case Action.RESTART:
          restart();
          break;
        case Action.NONE:
          onReceive(payload);
          break;
        default:
          print("Worker: unknown action -> $action");
      }
    } else {
      print("Worker: WARNING: incorrect message format, but still forwarding $message");
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
   * May be Future.sync() will become handy
   * So that only after onReceive is completed, DONE message is sent to router
   *
   * will this make it possible to include async calls in onReceive?
   */
  onReceive(var message);

  done([var message]) {
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.DONE, message));
  }

  void kill() {
    receivePort.close();
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.KILLED, null));
  }

  void restart() {
    receivePort.close();
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.RESTARTING, null));
  }
}
