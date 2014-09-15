library isolatesystem.router.Random;

import 'dart:isolate';
import 'dart:async';
import 'Router.dart';
import '../messages/Messages.dart';

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

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort); // anything along with sendport?
  Random randomRouter = new Random();
  receivePort.listen((message) {
    randomRouter._onReceive(message, sendport, receivePort);
  });
}

class Random implements Router {
  Map<Uri, Isolate> workerIsolates = new Map<Uri, Isolate>();
  List<SendPort> workersSendPorts = new List<SendPort>();


  _onReceive(message, sendport, receivePort) {
    if (message is SendPort) {
      workersSendPorts.add(sendport);
    } else if (message is String) {
      print("Random Router: $message");
    } else if (message is Event) {
      switch(message.action) {
        case(Action.SPAWN):
          Uri workerUri = Uri.parse(message.message["worker"]);
          int num = int.parse(message.message["count"]);
          Isolate.spawnUri(workerUri, null, receivePort.sendPort).then((isolate){
            workerIsolates.putIfAbsent(workerUri, isolate);
          });
        break;

        default:
        break;
      }
    }
  }
}