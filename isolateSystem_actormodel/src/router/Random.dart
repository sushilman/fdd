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

  Map<int, Isolate> workerIsolates = new Map<int, Isolate>();
  List<SendPort> workersSendPorts = new List<SendPort>();

  Random(List<String> args, this.sendPortOfController) {
    receivePort = new ReceivePort();
    SendPort self = receivePort.sendPort;
    sendPortOfController.send(receivePort.sendPort); // anything along with sendport?

    Uri workerUri = args[0];
    int workersCount = args[1];

    receivePort.listen((message) {
      _onReceive(message, receivePort);
    });

    spawnWorkers(receivePort, workerUri, workersCount);
  }

  _onReceive(var message, ReceivePort receivePort) {
    print("Router: $message");
    if (message is SendPort) {
      workersSendPorts.add(message);
    } else if (message is String) {
      //just select and forward the message
      selectWorkerSendPort().send(message);

    } else if (message is Event) {
      switch(message.action) {
        case(Action.SPAWN):
          //Do nothing
          //may be call spawnWorkers
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
      print("Spawning... $index");
      Isolate.spawnUri(workerUri, [index], receivePort.sendPort).then((isolate) {
        workerIsolates[index] = isolate;
        print("${workerIsolates.length} vs ${workersCount}");
        if(workerIsolates.length == workersCount) {
          sendPortOfController.send(Messages.createEvent(Action.READY, null));
        }
      });
      print("Spawned $index Worker ");
    }
  }

  SendPort selectWorkerSendPort() {
    Math.Random random = new Math.Random();
    int randomInt = 0;
    if(workersSendPorts.length > 0)
      randomInt = random.nextInt(workersSendPorts.length - 1);
    return workersSendPorts[randomInt];
  }

  /**
   * Checks if the isolate with given sendport is free
   */
  bool isFree(Isolate isolate) {
    ReceivePort rp = new ReceivePort();
    isolate.ping(rp.sendPort, Isolate.IMMEDIATE);
    rp.listen((message) {
      return true;
    });
  }
}