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
  SendPort _me;
  String id;

  /// Name is the name of the pool of isolate this isolate belongs to, i.e. router name
  String _poolName;
  String _deployedPath;

  String sender;
  String respondTo; // could be sender or some other isolate

  static const String TO = 'to';
  static const String SENDER = 'sender';
  static const String REPLY_TO = 'replyTo';
  static const String MESSAGE = 'message';

  String get poolName => _poolName;
  set poolName(String value) => _poolName = value;

  Worker(List<String> args, this.sendPort) {
    id = args.removeAt(0);
    _poolName = args.removeAt(0);
    _deployedPath;
    if(args.length > 1) {
      _deployedPath = args.removeAt(0);
      _log("PATH - $_deployedPath");
    }

    args = _extractExtraArguments(args);

    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.CREATED, receivePort.sendPort));
    receivePort.listen((var message) {
      _onReceive(message);
    });
  }

  Worker.withoutReadyMessage(List<String> args, this.sendPort) {
    id = args.removeAt(0);
    _poolName = args.removeAt(0);
    args = args[0];

    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    receivePort.listen(_onReceive, onDone:_onDone, cancelOnError:false);
  }

  _onDone() {
  }

  _onReceive(var message) {
    _log("Worker $id: $message");
    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);
      if(payload is Map && payload[MESSAGE].containsKey(SENDER)) {
        sender = payload[MESSAGE][SENDER];
      }
      if(payload is Map && payload[MESSAGE].containsKey(Worker.REPLY_TO)) {
        respondTo = payload[MESSAGE][Worker.REPLY_TO];
      }
      if(respondTo == null) {
        respondTo = sender;
      }

      switch(action) {
        case Action.KILL:
          kill();
          break;
        case Action.NONE:
          onReceive(payload[MESSAGE][MESSAGE]);
          break;
        default:
          _log("Worker: unknown action -> $action");
      }
    } else {
      _log("Worker: WARNING: incorrect message format, but still forwarding $message");
      onReceive(message);
    }

    /**
     * sending DONE here creates issues with Proxy Isolate
     * Because, proxy isolate further via websocket spawns another isolate which is also a child of Worker
     * Thus DONE message ends up being sent twice
     */
  }

  onReceive(var message);

  done() {
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.DONE, null));
  }

  /**
   * to -> send current message to isolatePool
   * replyTo -> after this message has been process, reply to my pool or forward to mentioned isolate
   *
   * === Some thoughts ===
   * May be add something like, reply specifically to me -> which would be similar to implementation of "ask"
   * also send uuid of self so that resulting message comes back to this isolate
   *
   * And may be the isolatesystem adds something too (whenever there is uuid attached in replyTo/replyExactlyTo) to identify itself?
   * so that the response comes exactly to same isolate of same system
   *
   * respondTo is the isolate set as replyTo be original sender
   */
  send(var message, String to, {String replyTo}) {
    var msg = {'sender':this.poolName,
               'to': to,
               'message': message,
               'replyTo': replyTo};

    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.SEND, msg));
  }

  reply(var message, {String replyTo}) {
    var msg = {'sender':this.poolName,
               'to': this.respondTo,
               'message': message,
               'replyTo': replyTo};

    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.REPLY, msg));
  }

  ask(var message, String to) {
    var msg = {'sender':this.id,
               'to': to,
               'message': message,
               'replyTo': this.id};

    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.ASK, msg));
  }

  void kill() {
    receivePort.close();
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.KILLED, null));
  }

  _extractExtraArguments(var args) {
    if(args[0] is List) {
      List<String> temp = new List<String>();
      temp.addAll(args[0]);
      args.clear();
      args.addAll(temp);
    } else {
      String temp = args[0];
      args.clear();
      args.add(temp);
    }
    return args;
  }

  _log(String text){
    //print(text);
  }
}
