library isolatesystem.worker.Worker;

import 'dart:isolate';

import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';

abstract class Worker {
  ReceivePort receivePort;
  SendPort sendPort;
  SendPort _me;
  String id;

  /// "me", in reality is the name of the pool of isolate this isolate belongs to, i.e. router name
  String me;
  String _deployedPath;

  String sender;
  String respondTo; // could be sender or some other isolate

  static const String TO = 'to';
  static const String SENDER = 'sender';
  static const String REPLY_TO = 'replyTo';
  static const String MESSAGE = 'message';

  Worker(List<String> args, this.sendPort) {
    id = args.removeAt(0);
    me = args.removeAt(0);
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

  Worker.internal(Map args) {
    id = args['id'];
    me = args['routerId'];
    this.sendPort = args['sendPort'];
    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    receivePort.listen(_onReceive, onDone:_onDone, cancelOnError:false);
  }

  _onDone() {
  }

  _onReceive(var message) {
    _log("Worker $id: $message");
    if(MessageUtil.isValidMessage(message)) {

      String action = MessageUtil.getAction(message);

      var payload = message;

      if(payload is Map && payload.containsKey(SENDER)) {
        sender = payload[SENDER];
      }
      if(payload is Map && payload.containsKey(Worker.REPLY_TO)) {
        respondTo = payload[Worker.REPLY_TO];
      }
      if(respondTo == null) {
        respondTo = sender;
      }

      if(action == null) {
        onReceive(payload['message']);
      } else {
        switch (action) {
          case Action.PING:
            _replyToPing();
            break;
          case Action.KILL:
            kill();
            break;
          default:
          //_log("Worker: unknown action -> $action");
        }
      }
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
   *
   * respondTo is the set as replyTo if present, else set to sender
   * sender is the original sender
   */
  send(var message, String to, {String replyTo}) {
    var msg = {'sender':this.me,
               'to': to,
               'message': message,
               'replyTo': replyTo};

    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.SEND, msg));
  }

  /**
   * Send reply message to sender
   * * [replyTo] reply path which can be set to some other isolate
   */
  reply(var message, {String replyTo}) {
    var msg = {'sender':this.me,
               'to': this.respondTo,
               'message': message,
               'replyTo': replyTo};

    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.REPLY, msg));
  }

  /**
   * Makes sure that this particular instance of worker will get the replied message
   */
  ask(var message, String to) {
    var msg = {'sender':this.id,
               'to': to,
               'message': message,
               'replyTo': this.id};

    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.ASK, msg));
  }

  void _kill() {
    receivePort.close();
    print("Killing WORKER $id");
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.KILLED, null));
    kill();
  }

  void kill() {
    // optional implementation and can be safely overridden
  }

  void _replyToPing() {
    sendPort.send(MessageUtil.create(SenderType.WORKER, id, Action.PONG, null));
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
