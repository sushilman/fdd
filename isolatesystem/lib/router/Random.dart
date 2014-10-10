library isolatesystem.router.Random;

import 'dart:isolate';
import 'dart:async';
import 'dart:math' as Math;
import 'dart:convert';

import 'package:uuid/uuid.dart';

import 'Router.dart';
import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';

/**
 * http://doc.akka.io/docs/akka/snapshot/scala/routing.html
 * each routee may have different path
 * i.e. may be spawned in different vm
 *
 * TODO:
 * What happens to remote isolates if a router is killed? -> may be gracefully ending that isolate is possible
 * But, if the machine in which the router exists goes down? -> memory leak in remote isolate?
 * So, may be we need to send heartbeat from time to time, if no heartbeat arrives then isolate
 * can try to contact router and if not reachable then just gracefully exit :)
 * Isolate.ping might come handy? -> not implemented in dart 1.6.0 yet
 * https://api.dartlang.org/apidocs/channels/be/dartdoc-viewer/dart-isolate.Isolate#id_ping
 *
 * Isolate.OnErrorListener and,
 * Isolate.OnExitListener
 * for supervision of errors? -> not implemented in dart 1.6.0 yet
 *
 * TODO: do not issue pull_request on done msg from the isolate,
 *       if it has been issued a kill or restart command
 *
 * TODO: BUG? if a message arrives in router, but it cannot send it anywhere, what happens to that message?
 */

main(List<String> args, SendPort sendPort) {
  Random randomRouter = new Random(args, sendPort);
}

class Random implements Router {
  String id;
  ReceivePort receivePort;
  SendPort sendPortOfController;
  SendPort me;

  List<_Worker> workers;
  List<String> workersPaths;
  Uri workerSourceUri;

  //TODO: can be removed, sending message to self seems far better approach
  List _bufferedMessages = new List();

  var extraArgs;

  Random(List<String> args, this.sendPortOfController) {
    receivePort = new ReceivePort();
    me = receivePort.sendPort;
    workers = new List<_Worker>();

    id = args[0];
    workerSourceUri = Uri.parse(args[1]);
    workersPaths = args[2];
    if(args.length > 3)
        extraArgs = args[3];

    sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.NONE, receivePort.sendPort));
    spawnWorkers(extraArgs);
    receivePort.listen(_onReceive);
  }

  _onReceive(var message) {
    _out("Router: $message");
    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);

      switch(senderType) {
        case SenderType.SELF:
        case SenderType.CONTROLLER:
          _handleMessageFromController(action, payload);
          break;
        case SenderType.EXTERNAL:
        case SenderType.PROXY:
        case SenderType.WORKER:
          _handleMessageFromWorker(action, senderId, payload, message);
          break;
        default:
          _out("Router: Unknown Sender Type -> $senderType, so discarding $message");
      }
    } else {
      _out ("Router: Unknown message: $message");
    }
  }

  _handleMessageFromController(String action, var payload) {
    switch(action) {
      case Action.SPAWN:
        //TODO: may be, to relocate individual isolate in same isolate system
        break;
      case Action.KILL:
        break;
      case Action.RESTART:
        break;
      case Action.KILL_ALL:
        break;
      case Action.RESTART_ALL:
        _restartAllWorkers();
        workers.clear();
        print('Clearing out workers');
        spawnWorkers(extraArgs);
        break;
      case Action.NONE:
        var tempMsg = MessageUtil.create(SenderType.CONTROLLER, id, Action.NONE, payload);
        if(workers.length == 0) {
          _out("Adding to buffer because no workers !");
          _bufferedMessages.add(tempMsg);
        } else {
          _out("find good worker !");
          _Worker worker = selectWorker();
          if(worker.sendPort == null) {
            _out("Adding to buffer because sendport is null");
            _bufferedMessages.add(tempMsg);
          } else {
            worker.sendPort.send(tempMsg);
            _out("sending $payload to worker ${worker._id}");
          }
        }
        //_out("message $payload Sent to worker ${worker.id}");
        break;
      default:
        _out("Router: Unknown action from Controller -> $action");
    }
  }

  _handleMessageFromWorker(String action, String senderId, var payload, var fullMessage) {
    switch(action) {
      case Action.CREATED:
//        _Worker worker = _getWorkerById(senderId);
//        if(worker == null) {
//          _out("Worker still NULL so sending same message to self, bad senderId/workerId?");
//          me.send(fullMessage);
//        } else {
//          _out("Router: Assigning sendport");
//          worker.sendPort = payload;
//          for(var m in _bufferedMessages) {
//            me.send(m);
//          }
//          _bufferedMessages.clear();
//        }
//
//        sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.CREATED, payload));
        _Worker worker = _getWorkerById(senderId);
        //TODO: fix for remote worker
        if(worker == null) {
          //print("Worker still NULL so creating new local worker?");
          _Worker w = new _Worker(senderId, "TODO: setpath", null);
          workers.add(w);
          w.sendPort = payload;
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.PULL_MESSAGE, null));
        } else {
          worker.sendPort = payload;
          _bufferedMessages.forEach((m) {
            me.send(m);
            _out("Router: clearing buffers and sending message to self $m" );
          });
          _bufferedMessages.clear();
        }

        if(areAllWorkersReady()) {
          print("### All workers are ready !! ###");
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.CREATED, null));
        }
        break;
      case Action.REPLY:
        sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.REPLY, payload));
        break;
      case Action.DONE:
      case Action.NONE:
        if(_getWorkerById(senderId) != null) {
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.PULL_MESSAGE, payload));
        }
        break;
      case Action.RESTARTING:
//        _Worker worker = _getWorkerById(senderId);
//        String path = worker.path;
//        workers.remove(worker);
//        Uuid uuid = new Uuid();
//       String newId = uuid.v1();
        break;
      default:
        _out("Routern: Unknown Action -> $action");
    }
  }

  spawnWorkers([args]) {
    var uuid = new Uuid();
    for (int index = 0; index < workersPaths.length; index++) {
      String path = workersPaths[index];
      String id = uuid.v1();
      spawnWorker(id, path, args:args);
    }
  }

  spawnWorker(String id, String path, {var args}) {
    id = "${this.id}/$id";
    Uri proxyUri = Uri.parse("../worker/Proxy.dart");
    if(path.startsWith("ws://")) {
      //_out("Spawning remote isolate");
      Isolate.spawnUri(proxyUri, [id, this.id, path, workerSourceUri, args], receivePort.sendPort).then((Isolate isolate) {
        _Worker w = new _Worker(id, path, isolate);
        workers.add(w);
      });
    } else {
      //_out("Spawning local isolate");
      Isolate.spawnUri(workerSourceUri, [id, this.id, path, args], receivePort.sendPort).then((Isolate isolate) {
        _Worker w = new _Worker(id, path, isolate);
        workers.add(w);
      });
    }
  }

  _restartWorker(String id) {
    _getWorkerById(id)
      ..active = false
      ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.RESTART, null));
    workers.remove(id);
  }

  /*
   * Simply restarting router instead of individual workers is NOT feasible
   * as response messages from the workers will could be lost
   *
   */
  _restartAllWorkers() {
    for(_Worker worker in workers) {
      worker
        ..active = false
        ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.RESTART, null));
    }
  }

  _killWorker(String id) {
    _getWorkerById(id)
      ..active = false
      ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.KILL, null));
    workers.remove(id);
  }

  _killAllWorkers() {
    for(_Worker worker in workers) {
      worker
        ..active = false
        ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.KILL, null));
    }
    workers.clear();
  }


  _Worker selectWorker() {
    Math.Random random = new Math.Random();
    int randomInt = 0;
    if(workers.length > 1) {
      randomInt = random.nextInt(workers.length);
    }
    //_out("Workers length: ${workers.length} , [0] -> ${workers[0].id}");
    return workers[randomInt];
  }

  bool areAllWorkersReady() {
    //_out("Are all workers ready? ${workers.length} vs ${workersPaths.length}");

    if(workers.length != workersPaths.length) {
      return false;
    }

    for (_Worker worker in workers) {
      try {
        if(worker.sendPort == null) {
          return false;
        }
      } catch (e) {
        return false;
      }
    }
    return true;
  }

  /**
   * Checks if the isolate with given sendport is free
   * send sendports of isolates to this monitoring isolate
   * so that it can ping and forward action?
   */

  _Worker _getWorkerById(String id) {
    for(_Worker worker in workers) {
      if(worker.id == id) {
        return worker;
      }
    }
    return null;
  }

  removeWorker(_Worker w) {
    workers.remove(w);
  }

  _out(String text) {
    print(text);
  }

}

/**
 * Simply a custom data type
 */
class _Worker {
  String _id;
  SendPort _sendPort;
  Isolate _isolate;
  String _path;
  bool _active = true;

  _Worker(this._id, this._path, this._isolate);

  set sendPort(SendPort value) => _sendPort = value;
  get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  get isolate => _isolate;

  set id(String value) => _id = value;
  get id => _id;

  set path(String value) => _path = value;
  get path => _path;

  set active(bool value) => _active = value;
  get active => _active;
}
