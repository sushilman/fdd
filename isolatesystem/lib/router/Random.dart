library isolatesystem.router.Random;

import 'dart:isolate';
import 'dart:async';
import 'Router.dart';
import '../action/Action.dart';
import 'dart:math' as Math;
import 'dart:convert';
import 'package:uuid/uuid.dart';

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
 * TODO: *important* Should be able to recognize if messages are from isolate or from controller
 */

main(List<String> args, SendPort sendPort) {
  Random randomRouter = new Random(args, sendPort);
}

class Random implements Router {
  ReceivePort receivePort;
  SendPort sendPortOfController;
  SendPort self;

  List<_Worker> workers;
  int workersCount;
  List<String> workersPaths;
  Uri workerSourceUri;

  Random(List<String> args, this.sendPortOfController) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;
    workers = new List<_Worker>();
    sendPortOfController.send(receivePort.sendPort);

    workerSourceUri = Uri.parse(args[0]);
    workersCount = int.parse(args[1]);
    workersPaths = JSON.decode(args[2]);
    //print("Paths : $workersPaths");

    spawnWorkers(receivePort, workerSourceUri, workersCount);

    receivePort.listen((message) {
      _onReceive(message, receivePort);
    });

  }

  _onReceive(var message, ReceivePort receivePort) {
    print("Router: $message");
    if (message is List) {
      if(message.length > 1 && message[1] is SendPort) {
        String id = message[0];
        SendPort sendPort = message[1];

        _Worker worker = getWorkerById(id);
        //TODO: create worker object only after receiving sendport message from the isolate
        //temporarily store other variables before creating isolate,
        // somewhere according to id and access it here

        if(worker == null) {
          _Worker w = new _Worker(id, "path", null);
          workers.add(w);
          w.sendPort = sendPort;
          print("Adding worker");
          sendPortOfController.send([Action.DONE]);
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
            sendPortOfController.send(message);
            break;
          case Action.KILL:
            String id = message[1];
            getWorkerById(id).sendPort.send([Action.KILL]);
            workers.remove(id);
            break;
          case Action.RESTART:
            String id = message[1];
            _restart(id);
            break;
          case Action.KILL_ALL:
            _killAll();
            break;
          case Action.RESTART_ALL:
            _restartAll();
            break;
          case Action.KILLED:
            //print("Isolate has been killed!");
            String id = message[1];
            workers.remove(getWorkerById(id));
            break;
          case Action.RESTARTING:
            String id = message[1];
            _Worker worker = getWorkerById(id);
            String path = worker.path;
            print(workers.remove(worker));
            print("After removal : ${workers.length}");
            //TODO: Refactor
            Uuid uuid = new Uuid();
            String newId = uuid.v1();
            Isolate.spawnUri(workerSourceUri, [newId], receivePort.sendPort);
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

  spawnWorkers(ReceivePort receivePort, Uri workerSourceUri, int workersCount) {
    Uri proxyUri = Uri.parse("/Users/sushil/fdd/isolatesystem/lib/worker/Proxy.dart");

    var uuid = new Uuid();
    for (int index = 0; index < workersPaths.length; index++) {
      String path = workersPaths[index];
      //print("Random: path $path");
      if(path.startsWith("ws://")) {
        String id = uuid.v1();
        Isolate.spawnUri(proxyUri, [id, path, workerSourceUri], receivePort.sendPort).then((Isolate isolate) {
          _Worker w = new _Worker(id, path, isolate);
          workers.add(w);
        });
      } else {
        String id = uuid.v1();
        Isolate.spawnUri(workerSourceUri, [id], receivePort.sendPort).then((Isolate isolate) {
          _Worker w = new _Worker(id, path, isolate);
          workers.add(w);
        });
      }
    }
  }

  _restart(String id) {
    getWorkerById(id).sendPort.send([Action.RESTART]);
    workers.remove(id);
  }

  _restartAll() {
    workers.forEach((worker) {
      worker.sendPort.send([Action.RESTART]);
    });
  }

  _kill(String id) {
    getWorkerById(id).sendPort.send([Action.KILL]);
    workers.remove(id);
  }

  _killAll() {
    workers.forEach((worker) {
      worker.sendPort.send([Action.KILL]);
    });
    workers.clear();
  }


  _Worker selectWorker() {
    Math.Random random = new Math.Random();
    int randomInt = 0;
    if(workers.length > 1) {
      randomInt = random.nextInt(workers.length);
    }
    print("Workers length: ${workers.length} , [0] -> ${workers[0].id}");
    return workers[randomInt];
  }

  bool areAllWorkersReady() {
    //print("Are all workers ready? ${workers.length} vs $workersCount");

    if(workers.length != workersCount) {
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

  _Worker getWorkerById(String id) {
    _Worker selectedWorker = null;
    workers.forEach((worker){
      //print("WorkerId: ${worker.id}");
    });

    //print("Reqd. id : $id");
    workers.forEach((worker) {
      if(worker.id == id) {
        selectedWorker = worker;
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

  //TODO: make use of control port instead of ping() method?
  Future<bool> isAlive() {
    Completer completer = new Completer();

    ReceivePort rp = new ReceivePort();
    //_isolate.controlPort.send("PING");
    //_isolate.addErrorListener(new ReceivePort().sendPort);
    //_isolate.kill(Isolate.IMMEDIATE);
    //_isolate.ping(rp.sendPort, Isolate.IMMEDIATE);
    rp.listen((message) {
      if(message == null) {
        completer.complete(true);
      }
    });
    return completer.future;
  }
}
