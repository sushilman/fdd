library isolatesystem.router.roundRobin;

import 'dart:isolate';
import 'Router.dart';
import '../worker/Worker.dart';

/**
 * Should be an isolate
 * Will be spawned by controller
 */
class RoundRobin implements Router {
  RoundRobin() {
  }

  List<Worker> workers;

  void spawnWorkers(int n, Uri isolateUri) {

  }

  List<Worker> selectWorkers() {

  }


}
