library isolatesystem.router.Random;

import 'dart:isolate';
import 'dart:convert';
import 'dart:async';

import 'package:uuid/uuid.dart';

import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';
import '../worker/Proxy.dart';

/**
 * TODO:
 * What happens to remote isolates if a router / isolate system is killed? -> may be gracefully ending that isolate is possible
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
 */

abstract class Router {
  static const String RANDOM = "random";
  static const String ROUND_ROBIN = "roundRobin";
  static const String BROADCAST = "broadcast";
  static const String CUSTOM = "custom";

  /**
   * timeout before pinging an idle worker
   */
  int TIMEOUT_MILLISECONDS  = 2000;

  String _id;
  ReceivePort _receivePort;
  SendPort _sendPortOfController;
  SendPort _me;

  List<Worker> workers;
  List<String> _workersPaths;
  Uri _workerSourceUri;

  var extraArgs;

  List _messageBuffer;

  Router(Map args) {
    this._sendPortOfController = args['sendPort'];
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    workers = new List<Worker>();
    _messageBuffer = new List();

    _id = args['id'];
    _workerSourceUri = Uri.parse(args['workerUri']);
    if(args['workerPaths'] is List) {
      _workersPaths = args['workerPaths'];
    } else {
      _log("Bad argument type");
      _workersPaths = JSON.decode(args['workerPaths']);
    }

    extraArgs = args['extraArgs'];

    _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.NONE, _receivePort.sendPort));
    _spawnWorkers(extraArgs);
    _receivePort.listen(_onReceive);
    _startMonitoringIdleWorkers();
  }

  /**
   * Return type should either be a single Worker
   * or List<Worker>
   * if a list is returned, message will be replicated to each worker
   */
  selectWorker();

  _onReceive(var message) {
    _log("Router: $message");
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
          _log("Router: Unknown Sender Type -> $senderType, so discarding $message");
      }
    } else {
      _log ("Router: Unknown message: $message");
    }
  }

  _handleMessageFromController(String action, var payload, var fullMessage) {
    switch(action) {
      case Action.SPAWN:
      //TODO: may be, to relocate individual isolate in same isolate system
        break;
      case Action.KILL:
        _killAllWorkers();
        _receivePort.close();
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
          //_me.send(fullMessage);
          _messageBuffer.add(fullMessage);
        } else {
          Worker worker;
          List<String> pathPieces = payload['to'].split('/');
          if (pathPieces.length >= 3) {
            // checking if it is a reply of ask
            worker = _getWorkerById(payload['to']);

            if (worker == null) {
              // if designated worker is not found, message is discarded
              _log("Worker with ${payload['to']} not found !");
              _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.PULL_MESSAGE, null));
            }
          } else {
            worker = selectWorker();
          }

          if (worker != null) {
            if (worker is List) {
              //in case router returns multiple workers
              for (Worker w in worker) {
                if(w.sendPort != null) {
                  w.sendPort.send(payload['message']);
                } else {
                  _messageBuffer.add(fullMessage);
                }
              }
            } else if (worker.sendPort == null) {
              //_me.send(fullMessage);
              _messageBuffer.add(fullMessage);
            } else {
              _log("Router -> Worker: ${payload['message']}");
              worker.sendPort.send(payload['message']);
            }
          }
        }
        break;

      default:
        _log("Router: Unknown action from Controller -> $action");
    }
  }

  _handleMessageFromWorker(String action, String senderId, var payload, var fullMessage) {
    _log("$action Sender: $senderId");
    Worker worker = _getWorkerById(senderId);
    if(worker != null) {
      worker.lastMessageTimestamp = new DateTime.now().millisecondsSinceEpoch;
      _log("Sender worker = ${worker.id}");
    } else {
      _log("Sender worker is NULL");
    }
    switch(action) {
      case Action.CREATED:
        if(worker == null) {
          _log("Worker still NULL so sending same message to self, bad senderId/workerId?");
          //_me.send(fullMessage);
          _messageBuffer.add(fullMessage);
        } else {
          _log("Router: Assigning sendport");
          worker.sendPort = payload;
          _flushBuffer();
          _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.CREATED, null));
        }
        break;

      case Action.DONE:
      case Action.NONE:
          _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.PULL_MESSAGE, null));
        break;
      case Action.SEND:
      case Action.REPLY:
        _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.SEND, payload));
        break;
      // In case of ASK, we need to dequeue from separate_individual queue, thus full-id of the worker is required in this case
      case Action.ASK:
        _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, senderId, Action.ASK, payload));
        break;
      case Action.KILLED:
      case Action.ERROR:
        _killWorker(worker);
        break;

      case Action.PONG:
        _log("Response to ping arrived!");
        // if a response has arrived before responding to ping, then ignore pull message.
        // This can be done by checking difference in timestamp, if it is higher than timeout or not.
        _sendPortOfController.send(MessageUtil.create(SenderType.ROUTER, _id, Action.PULL_MESSAGE, null));
        break;
      default:
        _log("Router: Unknown Action -> $action");
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
    if(path.startsWith("ws://")) {
      Isolate.spawn(proxyWorker, {'id':id, 'routerId':this._id, 'workerPath':path, 'workerSourceUri': _workerSourceUri, 'extraArgs':args, 'sendPort': _me}).then((Isolate isolate){
        Worker w = new Worker(id, path, isolate);
        workers.add(w);
      });
    } else {
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

  _killWorker(Worker worker) {
    if(worker != null) {
      worker.sendPort.send(MessageUtil.create(SenderType.ROUTER, this._id, Action.KILL, null));
      workers.remove(worker);
    }
  }

  _killAllWorkers() {
    for(Worker worker in workers) {
      worker.sendPort.send(MessageUtil.create(SenderType.ROUTER, this._id, Action.KILL, null));
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

  void _flushBuffer() {
    int len = _messageBuffer.length;
    for(int i = 0; i < len; i++) {
      _me.send(_messageBuffer.removeAt(0));
    }
  }

  _log(String text) {
    //print(text);
  }

  _pingWorker(Worker worker) {
    worker.sendPort.send(MessageUtil.create(SenderType.ROUTER, this._id, Action.PING, null));
  }

  // keep record of dequeue records sent by workers
  // if a worker has not sent a dequeue request in a while
  // send ping, if router replies to that ping
  // send dequeue request to controller
  // but if the worker sends a done/ask/none replies -> ignore response of ping as the
  // dequeue request will already be sent
  _startMonitoringIdleWorkers() {
    new Timer.periodic(const Duration(seconds:2), (Timer t) {
      int currentTimeStamp = new DateTime.now().millisecondsSinceEpoch;
      for(Worker w in workers) {
        if(w.lastMessageTimestamp == null) {
          continue;
        }

        int difference = currentTimeStamp - w.lastMessageTimestamp;
        if(difference > TIMEOUT_MILLISECONDS) {
          _pingWorker(w);
        }
      }
    });
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
  int _lastMessageTimestamp;

  Worker(this._id, this._path, this._isolate);

  set sendPort(SendPort value) => _sendPort = value;
  get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  get isolate => _isolate;

  set id(String value) => _id = value;
  get id => _id;

  set path(String value) => _path = value;
  get path => _path;

  int get lastMessageTimestamp => _lastMessageTimestamp;
  set lastMessageTimestamp(int value) => _lastMessageTimestamp = value;

}
