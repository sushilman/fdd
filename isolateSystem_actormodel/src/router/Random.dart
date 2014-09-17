library isolatesystem.router.Random;

import 'dart:isolate';
import 'dart:async';
import 'Router.dart';
import '../messages/Messages.dart';
import 'dart:math' as Math;

/**
 * http://doc.akka.io/docs/akka/snapshot/scala/routing.html
 * each routee may have different path
 * i.e. may be spawned in different vm
 *
 * Router need to store sendports, (receiveports?) and
 * locations where isolates are spawned (esp for remote isolates)
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
 */

main(List<String> args, SendPort sendPort) {
  Random randomRouter = new Random(args, sendPort);
}

class Random implements Router {
  ReceivePort receivePort;
  SendPort sendPortOfController;
  SendPort self;

  //Map<int, Isolate> workerIsolates = new Map<int, Isolate>();
  //List<SendPort> workersSendPorts = new List<SendPort>();

  List<_Worker> workers;

  Random(List<String> args, this.sendPortOfController) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;
    workers = new List<_Worker>();
    sendPortOfController.send(receivePort.sendPort); // anything along with sendport?

    Uri workerUri = args[0];
    int workersCount = args[1];

    spawnWorkers(receivePort, workerUri, workersCount);

    receivePort.listen((message) {
      _onReceive(message, receivePort);
    });

  }

  _onReceive(var message, ReceivePort receivePort) {
    //print("Router: $message");
    if (message is List && message[1] is SendPort) {
      int id = message[0];
      SendPort sendPort = message[1];
      _Worker worker = getWorkerById(id);
      worker.sendPort = sendPort;

      //TODO: deprecated
      //workersSendPorts.add(message);
    } else if (message is String) {
      //just select and forward the message
      _Worker w = selectWorker();

      //w.isAlive().then((alive) {
      //  if(alive){
          w.sendPort.send(message);
      //  } else {
      //   removeWorker(w);
          //spawn new worker?
      //  }
      //});
    } else if (message is Event) {
      switch(message.action) {
        case(Action.SPAWN):
          //Do nothing
          //may be call spawnWorkers
        break;

        case(Action.DONE):
          sendPortOfController.send(message);
        break;

        default:
          print("Unhandled message in Random Router: ${message.action}");
        break;
      }
    }
  }

  spawnWorkers(ReceivePort receivePort, Uri workerUri, int workersCount) {
    //print ("Spawning $workersCount workers of $workerUri");
    for(int index = 0; index < workersCount; index++) {
      //print("Spawning... $index");
      Isolate.spawnUri(workerUri, [index], receivePort.sendPort).then((Isolate isolate) {
        //workerIsolates[index] = isolate;
        workers.add(new _Worker(index, isolate));
        if(workers.length == workersCount) {
          sendPortOfController.send(Messages.createEvent(Action.READY, null));
        }
      });
      //print("Spawned $index Worker ");
    }
  }

  _Worker selectWorker() {
    Math.Random random = new Math.Random();
    int randomInt = 0;
    if(workers.length > 1) {
      randomInt = random.nextInt(workers.length - 1);
    }
    //print("Selected Worker id: $randomInt vs ${workers[randomInt].id}");
    return workers[randomInt];
  }

  /**
   * Checks if the isolate with given sendport is free
   *
   * TODO: think about moving this to another separate isolate/actor
   * send sendports of isolates to this monitoring isolate so that it can ping and forward messages?
   */

  _Worker getWorkerById(int id) {
    _Worker selectedWorker = null;
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

class _Worker {
  int _id;
  SendPort _sendPort;
  Isolate _isolate;

  _Worker(this._id, this._isolate);

  set sendPort(SendPort value) => _sendPort = value;
  get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  get isolate => _isolate;

  set id(int value) => _id = value;
  get id => _id;

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
