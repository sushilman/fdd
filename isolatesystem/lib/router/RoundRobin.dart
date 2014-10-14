import 'dart:isolate';
import 'dart:math' as Math;

import 'Router.dart';

main(List<String> args, SendPort sendPort) {
  RoundRobin randomRouter = new RoundRobin(args, sendPort);
}

class RoundRobin extends Router {
  int counter = 0;

  RoundRobin(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  Worker selectWorker() {
    int totalWorkers = workers.length;
    int index = counter % totalWorkers;
    counter++;

    if(counter >= totalWorkers) {
      counter = 0;
    }
    return workers[index];
  }
}