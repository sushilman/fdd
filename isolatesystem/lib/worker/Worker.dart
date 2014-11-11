library isolatesystem.worker.Worker;

import 'dart:isolate';
import 'dart:convert';
import 'dart:async';

import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';

abstract class Worker {
  ReceivePort workerReceivePort;
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

    workerReceivePort = new ReceivePort();
    _me = workerReceivePort.sendPort;
    sendPort.send([SenderType.WORKER, id, Action.CREATED, workerReceivePort.sendPort]);
    workerReceivePort.listen((var message) {
      _onReceive(message);
    });
  }

  Worker.internal(Map args) {
    id = args['id'];
    me = args['routerId'];
    this.sendPort = args['sendPort'];
    workerReceivePort = new ReceivePort();
    _me = workerReceivePort.sendPort;
    workerReceivePort.listen(_onReceive, onDone:_onDone, cancelOnError:false);
  }

  _onDone() {
  }

  _onReceive(var message) {
    _log("Worker $id: $message");
    if(MessageUtil.isValidMessage(message)) {
      if(message is String) {
        message = JSON.decode(message);
      }

      String senderType = MessageUtil.getSenderType(message);

      /**
       * SenderType controller is applicable for FileMonitor
       */
      if(senderType == SenderType.ROUTER || senderType == SenderType.PROXY || senderType == SenderType.CONTROLLER) {
        String action = MessageUtil.getAction(message);
        var payload = MessageUtil.getPayload(message);
        if(payload is Map && payload.containsKey(SENDER)) {
          sender = payload[SENDER];
        }
        if(payload is Map && payload.containsKey(Worker.REPLY_TO)) {
          respondTo = payload[Worker.REPLY_TO];
        }
        if(respondTo == null) {
          respondTo = sender;
        }


        if(action == Action.NONE) {
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
      } else {
        onReceive(message);
      }
    } else {
      onReceive(message);
    }


    /**
     * sending DONE here creates issues with Proxy Isolate
     * Because, proxy isolate further via websocket spawns another isolate which is also a child of Worker
     * Thus DONE message ends up being sent twice
     */
  }

  onReceive(var message);

  /**
   * Once the operations on a message is complete, this method must be invoked
   * to further dequeue messages from its queue from Message Queuing System
   */
  done() {
    _sendToRouter(MessageUtil.create(SenderType.WORKER, id, Action.DONE, null));
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

    _sendToRouter(MessageUtil.create(SenderType.WORKER, id, Action.SEND, msg));
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

    _sendToRouter(MessageUtil.create(SenderType.WORKER, id, Action.REPLY, msg));
  }

  /**
   * Makes sure that this particular instance of worker will get the replied message
   * Ask automatically sends request to dequeue from its queue
   */
  ask(var message, String to) {
    var msg = {'sender':this.id,
               'to': to,
               'message': message,
               'replyTo': this.id};

    _sendToRouter(MessageUtil.create(SenderType.WORKER, id, Action.ASK, msg));
  }

  void kill() {
    print ("KILL CALLED");
    beforeKill().then((_) => _forceKill(), onError: () => _forceKill());
  }

  void _forceKill() {
    workerReceivePort.close();
    _log("Killing WORKER $id");
    _sendToRouter(MessageUtil.create(SenderType.WORKER, id, Action.KILLED, null));

    throw "Hack to Forcefully Shutdown Isolate -> $id";
  }

  Future beforeKill() {
    // optional implementation and can be safely overridden
    return new Future.value(null);
  }

  void _sendToRouter (var message) {
    sendPort.send(JSON.encode(message));
  }

  void _replyToPing() {
    _sendToRouter(MessageUtil.create(SenderType.WORKER, id, Action.PONG, null));
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
