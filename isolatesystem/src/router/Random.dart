library isolatesystem.router.random;

import 'dart:isolate';
import 'dart:io';
import 'Router.dart';
import '../worker/Worker.dart';

/**
 * Should be an isolate
 * Will be spawned by controller
 */
class Random implements Router {
  List<Worker> workers;
  int numberOfWorkers;


  Random() {
    workers = new List<Worker>();
  }


  void spawnWorkers(int n, Uri isolateUri) {
    this.numberOfWorkers = n;

    for(int i  = 0; i<n; i++) {
      Worker worker = new Worker(isolateUri);
      workers.add(worker);

      //Temporary just for test
      sleep(new Duration(seconds:2));
      worker.start();
    }
  }

  List<Worker> selectWorkers() {

  }
}
