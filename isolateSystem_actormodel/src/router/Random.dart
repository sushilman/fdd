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
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort); // anything along with sendport?
  Random randomRouter = new Random();
  Uri workerUri = args[0];
  int workersCount = args[1];

  receivePort.listen((message) {
    randomRouter._onReceive(message, receivePort);
  });

  randomRouter.spawnWorkers(receivePort, workerUri, workersCount);
}

class Random implements Router {
  Map<Uri, Isolate> workerIsolates = new Map<Uri, Isolate>();
  List<SendPort> workersSendPorts = new List<SendPort>();


  _onReceive(message, receivePort) {
    //print("inside random.dart");
    if (message is SendPort) {
      workersSendPorts.add(message);
    } else if (message is String) {
      //TODO: for now just forwarding the message
      selectWorkerSendPort().send(message);

    } else if (message is Event) {
      switch(message.action) {
        case(Action.SPAWN):
          //Do nothing
          //may be call spawnWorkers
        break;

        default:
          print("Action NONE, Random Router: $message");
        break;
      }
    }
  }

  spawnWorkers(ReceivePort receivePort, Uri workerUri, int workersCount) {
    //print ("Spawning $workersCount workers of $workerUri");
    for(int index = 0; index < workersCount; index++) {
      Isolate.spawnUri(workerUri, [index], receivePort.sendPort).then((isolate) {
        workerIsolates[workerUri] = isolate;
      });
      //print("Spawning $index Worker ");
    }
  }

  SendPort selectWorkerSendPort() {
    Math.Random random = new Math.Random();
    int randomInt = random.nextInt(workersSendPorts.length);
    return workersSendPorts[randomInt];
  }
}