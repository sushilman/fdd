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
  SendPort self;

  List<_Worker> workers;
  List<String> workersPaths;
  Uri workerSourceUri;

  Random(List<String> args, this.sendPortOfController) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;
    workers = new List<_Worker>();

    id = args[0];
    workerSourceUri = Uri.parse(args[1]);
    workersPaths = args[2];

    sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.NONE, receivePort.sendPort));

    //print("Paths : $workersPaths");

    spawnWorkers();

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
      case Action.READY:
        _Worker worker = _getWorkerById(senderId);

        //TODO: fix for remote worker
        if(worker == null) {
          print("Worker still NULL so creating new local worker?");
          _Worker w = new _Worker(senderId, "TODO: setpath", null);
          workers.add(w);
          w.sendPort = payload;
          print("Adding worker");
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.PULL_MESSAGE, null));
        } else {
          worker.sendPort = payload;
        }

        if(areAllWorkersReady()) {
          //print("### All workers are ready !! ###");
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.READY, null));
        }
        break;
      case Action.DONE:
        if(_getWorkerById(senderId).active) {
          sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.PULL_MESSAGE, payload));
        }
        break;
      case Action.RESTARTING:
        _Worker worker = _getWorkerById(senderId);
        String path = worker.path;
        print(workers.remove(worker));
        print("After removal : ${workers.length}");
        //TODO: Refactor
        Uuid uuid = new Uuid();
        String newId = uuid.v1();
        spawnWorker(newId, path);
        break;
      case Action.NONE:
        break;
    }
  }

  _onReceive1(var message, ReceivePort receivePort) {
    print("Router: $message");
    if (message is List) {
      if(message.length > 1 && message[1] is SendPort) {
        String id = message[0];
        SendPort sendPort = message[1];

        _Worker worker = _getWorkerById(id);
        //create worker object only after receiving sendport message from the isolate
        //temporarily store other variables like path, before restarting/creating isolate,
        //somewhere according to id and access it here
        // or let the spawned isolate send the path in its message

        if(worker == null) {
          _Worker w = new _Worker(id, "path", null);
          workers.add(w);
          w.sendPort = sendPort;
          print("Adding worker");
          sendPortOfController.send([Action.PULL_MESSAGE]);
          //sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, id, Action.PULL_MESSAGE, null))
        } else {
          worker.sendPort = sendPort;
        }
        //print("Router: sendport added for $id");

        if(areAllWorkersReady()) {
          //print("### All wokers are ready !! ###");
          sendPortOfController.send([Action.READY]);
        }
      } else {
        switch (message[0]) {
          case Action.SPAWN:
          // TODO: spawn isolate, may be?
            break;
          case Action.DONE:
            String id = message[1];
            if(_getWorkerById(id).active) {
              message[0] = Action.PULL_MESSAGE;
              sendPortOfController.send(message);
            }
            break;
          case Action.KILL:
            String id = message[1];
            _getWorkerById(id).sendPort.send([Action.KILL]);
            workers.remove(id);
            break;
          case Action.RESTART:
            String id = message[1];
            _restartWorker(id);
            break;
          case Action.KILL_ALL:
            _killAllWorkers();
            break;
          case Action.RESTART_ALL:
            _restartAllWorkers();
            break;
          case Action.KILLED:
            //print("Isolate has been killed!");
            String id = message[1];
            workers.remove(_getWorkerById(id));
            break;
          case Action.RESTARTING:
            String id = message[1];
            _Worker worker = _getWorkerById(id);
            String path = worker.path;
            print(workers.remove(worker));
            print("After removal : ${workers.length}");
            //TODO: Refactor
            Uuid uuid = new Uuid();
            String newId = uuid.v1();
            spawnWorker(newId, path);
            //Isolate.spawnUri(workerSourceUri, [newId], receivePort.sendPort);
//            .then((Isolate isolate) {
//              //_Worker w = new _Worker(id, path, isolate);
//              //workers.add(w);
//            });
            break;
          default:
            //print("RandomRouter: Unknown Action: ${message[0]}");
            _Worker w = selectWorker();
            //print("Sending message: $message to ${w.id}");
            w.sendPort.send(message);
            break;
        }
      }
    } else if (message is String) {
      //just select and forward the message
      //TODO: check if worker is alive?
      // remove if not alive
      _Worker w = selectWorker();
      //print("Sending message: $message to ${w.id}");
      w.sendPort.send(message);
    }
  }

  spawnWorkers() {
    var uuid = new Uuid();
    for (int index = 0; index < workersPaths.length; index++) {
      String path = workersPaths[index];
      String id = uuid.v1();
      spawnWorker(id, path);
    }
  }

  spawnWorker(String id, String path) {
    Uri proxyUri = Uri.parse("/Users/sushil/fdd/isolatesystem/lib/worker/Proxy.dart");
    if(path.startsWith("ws://")) {
      print("Spawning remote isolate");
      Isolate.spawnUri(proxyUri, [id, path, workerSourceUri], receivePort.sendPort).then((Isolate isolate) {
        _Worker w = new _Worker(id, path, isolate);
        workers.add(w);
      });
    } else {
      print("Spawning local isolate");
      Isolate.spawnUri(workerSourceUri, [id, path], receivePort.sendPort).then((Isolate isolate) {
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
   *
   * TODO: think about moving this to another separate isolate/actor
   * send sendports of isolates to this monitoring isolate so that it can ping and forward action?
   */

  _Worker _getWorkerById(String id) {
    _Worker selectedWorker = null;
    workers.forEach((worker) {
      print("Reqd. id : $id vs woker id : ${worker.id}");
      if(worker.id == id) {
        selectedWorker = worker;
        //return worker; //Why now simply this instead of variable declarations and all
      }
    });
    //(selectedWorker == null) ? print("RETURNING NULL") : print("returning good worker");
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

  _Worker(this._id, this._path, this._isolate) {
    //print ("_Worker: worker with $id created");
  }

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
