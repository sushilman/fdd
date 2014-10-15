/**
 * http://doc.akka.io/docs/akka/snapshot/scala/routing.html
 * each routee may have different path
 * i.e. may be spawned in different vm
 *
 * TODO: routers should have id, which can be as simple as integer numbers
 */

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
 * But, if the machine(?) in which the router exists goes down? -> memory leak in remote isolate?
 * So, may be we need to send heartbeat from time to time, if no heartbeat arrives then isolate
 * can try to contact router and if not reachable then just gracefully exit :)
 * Isolate.ping might come handy? -> not implemented in dart 1.6.0 yet
 * https://api.dartlang.org/apidocs/channels/be/dartdoc-viewer/dart-isolate.Isolate#id_ping
 *
 * Isolate.OnErrorListener and,
 * Isolate.OnExitListener
 * for supervision of errors? -> not implemented in dart 1.6.0 yet
 *
 * do not issue pull_request on done msg from the isolate,
 *       if it has been issued a kill or restart command
 *
 * TODO: If a message arrives in router, but it cannot send it anywhere, Throw an Exception, (escalate to controller)
 *
 */

/**
 * TODO: Keep record of the workers, who issued DONE / REPLY  => which is a pull request
 * -> for, alternative load balancing ideas
 * -> this will also help to track unfulfilled pull requests
 */
abstract class Router {
  static const String RANDOM = "random";
  static const String ROUND_ROBIN = "roundRobin";
  static const String BROADCAST = "broadcast";

  String _id;
  ReceivePort _receivePort;
  SendPort _sendPortOfController;
  SendPort _me;

  List<Worker> workers;
  List<String> _workersPaths;
  Uri _workerSourceUri;

  var extraArgs;

  Router(List<String> args, this._sendPortOfController) {
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    workers = new List<Worker>();

    _id = args[0];
    _workerSourceUri = Uri.parse(args[1]);
    _workersPaths = args[2];
    if(args.length > 3)
      extraArgs = args[3];

    _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.NONE, _receivePort.sendPort));
    _spawnWorkers(extraArgs);
    _receivePort.listen(_onReceive);
  }

  Worker selectWorker();

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
          _handleMessageFromController(action, payload, message);
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

  _handleMessageFromController(String action, var payload, var fullMessage) {
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
        _killAllWorkers();
        _spawnWorkers(extraArgs);
        break;
      case Action.NONE:
        if(workers.length == 0) {
          _me.send(fullMessage);
        } else {
          Worker worker = selectWorker();
          if(worker.sendPort == null) {
            _me.send(fullMessage);
          } else {
            worker.sendPort.send(fullMessage);
          }
        }
        break;
      default:
        _out("Router: Unknown action from Controller -> $action");
    }
  }

  _handleMessageFromWorker(String action, String senderId, var payload, var fullMessage) {
    switch(action) {
      case Action.CREATED:
        Worker worker = _getWorkerById(senderId);
        if(worker == null) {
          _out("Worker still NULL so sending same message to self, bad senderId/workerId?");
          _me.send(fullMessage);
        } else {
          _out("Router: Assigning sendport");
          worker.sendPort = payload;
          _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.CREATED, null));
        }
        break;
      case Action.REPLY:
        _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.REPLY, payload));
        break;
      case Action.DONE:
      case Action.NONE:
        if(_getWorkerById(senderId) != null) {
          _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.PULL_MESSAGE, null));
        }
        break;
      default:
        _out("Router: Unknown Action -> $action");
    }
  }

  _spawnWorkers([args]) {
    var uuid = new Uuid();
    for (int index = 0; index < _workersPaths.length; index++) {
      String path = _workersPaths[index];
      String id = uuid.v1();
      _spawnWorker(id, path, args:args);
    }
  }

  _spawnWorker(String id, String path, {var args}) {
    id = "${this._id}/$id";
    Uri proxyUri = Uri.parse("../worker/Proxy.dart");
    if(path.startsWith("ws://")) {
      //_out("Spawning remote isolate");
      Isolate.spawnUri(proxyUri, [id, this._id, path, _workerSourceUri, args], _receivePort.sendPort).then((Isolate isolate) {
        Worker w = new Worker(id, path, isolate);
        workers.add(w);
      });
    } else {
      //_out("Spawning local isolate");
      Isolate.spawnUri(_workerSourceUri, [id, this._id, path, args], _receivePort.sendPort).then((Isolate isolate) {
        Worker w = new Worker(id, path, isolate);
        workers.add(w);
      });
    }
  }

  _restartWorker(String id) {
    _getWorkerById(id).sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.RESTART, null));
    workers.remove(id);
  }

  /*
   * Simply restarting router instead of individual workers is NOT feasible
   * as response messages from the workers will could be lost
   *
   */

  _killWorker(String id) {
    _getWorkerById(id).sendPort.send(MessageUtil.create(SenderType.ROUTER, id, Action.KILL, null));
    workers.remove(id);
  }

  _killAllWorkers() {
    for(Worker worker in workers) {
      worker.sendPort.send(MessageUtil.create(SenderType.ROUTER, _id, Action.KILL, null));
    }
    workers.clear();
  }

  bool _areAllWorkersReady() {
    //_out("Are all workers ready? ${workers.length} vs ${workersPaths.length}");

    if(workers.length != _workersPaths.length) {
      return false;
    }

    for (Worker worker in workers) {
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

  Worker _getWorkerById(String id) {
    for(Worker worker in workers) {
      if(worker.id == id) {
        return worker;
      }
    }
    return null;
  }

  removeWorker(Worker w) {
    workers.remove(w);
  }

  _out(String text) {
    //print(text);
  }

}

/**
 * Simply a custom data type
 */
class Worker {
  String _id;
  SendPort _sendPort;
  Isolate _isolate;
  String _path;

  Worker(this._id, this._path, this._isolate);

  set sendPort(SendPort value) => _sendPort = value;
  get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  get isolate => _isolate;

  set id(String value) => _id = value;
  get id => _id;

  set path(String value) => _path = value;
  get path => _path;
}
