library isolatesyste.controller;

import 'dart:isolate';

import '../router/Router.dart';
import '../router/RoundRobin.dart';


class Controller {
  Controller(Uri isolateUri, [Router router, int numberOfWorkers]) {
    if(router == null) {
      router = new RoundRobin();
    }

    router
      ..spawnWorkers(numberOfWorkers, isolateUri)
      ..selectWorker();
  }
}
