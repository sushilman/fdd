library isolatesystem.core;

/**
 * Isolate system - Analogous to Actor system
 *
 * Isolate system can be started with specified routing method
 * else a default method is chosen (roundrobin)
 *
 * Delegates to Controller to spawn everything?
 * or we can modify this as a controller
 */
import 'router/Router.dart';
import 'controller/Controller.dart';

class IsolateSystem {

  String name;

  IsolateSystem(String name, Uri isolateUri, [Router router, int numberOfWorkers]) {

    this.name = name;
    new Controller(isolateUri, router, numberOfWorkers);

  }
}
