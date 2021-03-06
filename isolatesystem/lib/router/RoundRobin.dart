library isolatesystem.router.RoundRobin;

import 'Router.dart';

roundRobin(Map args) {
  new RoundRobin(args);
}

class RoundRobin extends Router {
  int counter = 0;

  RoundRobin(Map args) : super(args);

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
