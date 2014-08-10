library isolatesystem.router.broadcast;

import 'dart:isolate';
import 'Router.dart';
import '../worker/Worker.dart';

/**
 * Should be an isolate
 * Will be spawned by controller
 */
class Broadcast implements Router {
  Broadcast() {
  }

  List<Worker> workers;

  void spawnWorkers(int n, Uri isolateUri) {

  }

  List<Worker> selectWorkers() {

  }


}
