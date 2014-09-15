library isolatesystem.router.random;

import 'dart:isolate';
import 'dart:io';
import 'dart:math' as Math;

import 'Router.dart';
import '../worker/Worker.dart';

/**
 * Should be an isolate
 * Will be spawned by controller
 *
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
    }
  }

  @override
  Worker selectWorker() {
    int randomWorkerNumber = new Math.Random().nextInt(workers.length);
    return workers[randomWorkerNumber];
  }

  @override
  List<Worker> selectAll() {
    return workers;
  }

}
