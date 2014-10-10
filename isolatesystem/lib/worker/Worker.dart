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
  SendPort me;
  String id;

  /// Name is the name of the pool of isolate this isolate belongs to, i.e. router name
  String _poolName;
  String _deployedPath;
  String replyTo;

  static const String TO = 'to';
  static const String REPLY_TO = 'replyTo';

  String get poolName => _poolName;
  set poolName(String value) => _poolName = value;

  Worker(List<String> args, this.sendPort) {
    id = args.removeAt(0);
    _poolName = args.removeAt(0);
    _deployedPath;
    if(args.length > 1) {
      _deployedPath = args.removeAt(0);
      _out("PATH - $_deployedPath");
    }

    args = _extractExtraArguments(args);

    receivePort = new ReceivePort();
    me = receivePort.sendPort;
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
    me = receivePort.sendPort;
    receivePort.listen(_onReceive, onDone:_onDone, cancelOnError:false);
  }

  _onDone() {
  }

  _onReceive(var message) {
    _out("Worker $id: $message");
    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);
      if(payload is Map && payload.containsKey('replyTo')) {
        replyTo = payload[Worker.REPLY_TO];
      }

      switch(action) {
        case Action.KILL:
          kill();
          break;
        case Action.NONE:
          onReceive(payload['message']);
          break;
        default:
          _out("Worker: unknown action -> $action");
      }
    } else {
      _out("Worker: WARNING: incorrect message format, but still forwarding $message");
      onReceive(message);
    }

    /**
     * sending DONE here creates issues with Proxy Isolate
     * Because, proxy isolate further via websocket spawns another isolate which is also a child of Worker
     * Thus DONE message ends up being sent twice
     */
  }

  onReceive(var message);

  done([var message]) {
    var msg = {'to': this.replyTo, 'message': message };
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.DONE, msg));
  }

  reply(var message, {String replyTo}) {
    var msg = {'to': this.replyTo, 'message': message, 'replyTo': replyTo != null ? replyTo : _poolName};
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.REPLY, msg));
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

  _out(String text){
    //print(text);
  }
}
