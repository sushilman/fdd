library isolatesystem.worker;

import 'dart:isolate';
import 'dart:async';

/**
 * Is simply an isolate that does tasks
 * Can spawn temporary isolates
 */
class Worker {

  ReceivePort port;
  Worker (Uri isolateUri)
  {
    port = new ReceivePort();
    List<String> args = new List();
    args.add(port.sendPort);
    Isolate.spawnUri(isolateUri, port.sendPort, null);
    print ("Isolate Created!");
  }

  /**
   * get the isolate to start working
   */
  start() {
    port.sendPort.send("hello");
  }

}
