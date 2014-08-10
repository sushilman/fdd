library isolatesystem.router.router;

import '../worker/Worker.dart';

/**
 * Interface
 *
 * All routers should be isolates
 * that will be spawned by controllers
 *
 */
abstract class Router {

  Router();

  List<Worker> workers;

  void spawnWorkers(int n, Uri isolateUri);

  /**
   * Returns selected worker or workers based on router algorithm/method of current router
   */
  List<Worker> selectWorkers();

}
