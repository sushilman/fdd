library isolatesystem.router.Broadcast;

import 'Router.dart';

broadcast(Map args) {
  new Broadcast(args);
}

class Broadcast extends Router {

  Broadcast(Map args):super(args);

  @override
  List<Worker> selectWorker() {
    return workers;
  }
}
