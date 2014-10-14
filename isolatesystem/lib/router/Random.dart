import 'dart:isolate';
import 'dart:math' as Math;

import 'Router.dart';

main(List<String> args, SendPort sendPort) {
  Random randomRouter = new Random(args, sendPort);
}

class Random extends Router {
  Random(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  Worker selectWorker() {
    Math.Random random = new Math.Random();
    int randomInt = 0;
    if(workers.length > 1) {
      randomInt = random.nextInt(workers.length);
    }
    return workers[randomInt];
  }
}