/**
 * http://doc.akka.io/docs/akka/snapshot/scala/routing.html
 * each routee may have different path
 * i.e. may be spawned in different vm
 */
class Router {
  static String RANDOM = "random";
  static String ROUND_ROBIN = "roundRobin";
  static String BROADCAST = "broadcast";


}