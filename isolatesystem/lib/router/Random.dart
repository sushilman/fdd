import 'dart:isolate';
import 'dart:math' as Math;

import 'Router.dart';

random(Map args) {
  Random randomRouter = new Random(args);
}

class Random extends Router {
  Random(Map args) : super(args);

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