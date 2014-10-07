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
 * Isolate.ping might come handy?
 * https://api.dartlang.org/apidocs/channels/be/dartdoc-viewer/dart-isolate.Isolate#id_ping
 *
 * Isolate.OnErrorListener and,
 * Isolate.OnExitListener
 * for supervision of errors?
 *
 * TODO: do not issue pull_request on done msg from the isolate,
 * TODO: if it has been issued a kill or restart command
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

  Random(List<String> args, this.sendPortOfController) {
    receivePort = new ReceivePort();
    me = receivePort.sendPort;
    workers = new List<_Worker>();


    id = args[0];
    workerSourceUri = Uri.parse(args[1]);
    workersPaths = args[2];
    var extraArgs;
  if(args.length > 3)
      extraArgs = args[3];

    sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.NONE, receivePort.sendPort));
    spawnWorkers(extraArgs);
    receivePort.listen(_onReceive);
  }

  _onReceive(var message) {
    print("Router: $message");
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
          _handleMessageFromWorker(action, senderId, payload);
          break;
        default:
          print("Router: Unknown Sender Type -> $senderType");
      }
    } else {
      print ("Router: Unknown message: $message");
    }
  }

  _handleMessageFromController(String action, var payload) {
    switch(action) {
      case Action.SPAWN:
        //TODO: may be used if you want to relocate individual isolate in same isolate system
        break;
      case Action.KILL:
        break;
      case Action.RESTART:
        break;
      case Action.KILL_ALL:
        break;
      case Action.RESTART_ALL:
        _restartAllWorkers();
        break;
      case Action.NONE:
        _Worker worker = selectWorker();
        worker.sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.NONE, payload));
        //print("message $payload Sent to worker ${worker.id}");
        break;
      default:
        print("Router: Unknown action from Controller -> $action");
    }
  }

  _handleMessageFromWorker(String action, String senderId, var payload) {
    switch(action) {
      case Action.CREATED:
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
        }

        if(areAllWorkersReady()) {
          //print("### All workers are ready !! ###");
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.CREATED, null));
        }
        break;
      case Action.REPLY:
        sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.REPLY, payload));
        break;
      case Action.DONE:
      case Action.NONE:
        if(_getWorkerById(senderId).active) {
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.PULL_MESSAGE, payload));
        }
        break;
      case Action.RESTARTING:
        _Worker worker = _getWorkerById(senderId);
        String path = worker.path;
        workers.remove(worker);
        Uuid uuid = new Uuid();
        String newId = uuid.v1();
        spawnWorker(newId, path);
        break;
      default:
        print("Routern: Unknown Action -> $action");
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
    Uri proxyUri = Uri.parse("../worker/Proxy.dart");
    if(path.startsWith("ws://")) {
      //print("Spawning remote isolate");
      Isolate.spawnUri(proxyUri, [id, this.id, path, workerSourceUri, args], receivePort.sendPort).then((Isolate isolate) {
        _Worker w = new _Worker(id, path, isolate);
        workers.add(w);
      });
    } else {
      //print("Spawning local isolate");
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
    workers.forEach((worker) {
      worker
        ..active = false
        ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.RESTART, null));
    });
  }

  _killWorker(String id) {
    _getWorkerById(id)
      ..active = false
      ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.KILL, null));
    workers.remove(id);
  }

  _killAllWorkers() {
    workers.forEach((worker) {
      worker
        ..active = false
        ..sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.KILL, null));
    });
    workers.clear();
  }


  _Worker selectWorker() {
    Math.Random random = new Math.Random();
    int randomInt = 0;
    if(workers.length > 1) {
      randomInt = random.nextInt(workers.length);
    }
    //print("Workers length: ${workers.length} , [0] -> ${workers[0].id}");
    return workers[randomInt];
  }

  bool areAllWorkersReady() {
    //print("Are all workers ready? ${workers.length} vs $workersCount");

    if(workers.length != workersPaths.length) {
      return false;
    }

    for(int i = 0; i < workers.length; i++) {
      _Worker worker = workers[i];
      try {
        if(worker.sendPort == null) {
          //print("Returning false");
          return false;
        }
      } catch (e) {
        //print("Error $e -> returning false");
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
    _Worker selectedWorker = null;
    workers.forEach((worker) {
      if(worker.id == id) {
        selectedWorker = worker;
      }
    });
    return selectedWorker;
  }

  removeWorker(_Worker w) {
    workers.remove(w);
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
