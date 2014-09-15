library isolatesystem.worker;

import 'dart:isolate';
import 'dart:async';

/**
 * Is simply an isolate that does tasks
 * Can spawn temporary isolates
 */
class Worker {

  ReceivePort receivePort;
  SendPort sendPort;
  Worker (Uri isolateUri)
  {
    receivePort = new ReceivePort();
    List<String> args = new List();
    args.add(receivePort.sendPort);
    Isolate.spawnUri(isolateUri, receivePort.sendPort, null);
    print ("Isolate Created!");
    receivePort.listen(_onReceive);
  }

  _onReceive(message) {
    if(message is SendPort) {
      sendPort = message;
      sendPort.send("PING");
    } else if (message is String) {
      print ("received by worker: $message");
      sendPort.send("PONG");
    }
  }
  /**
   * test the isolate if they are alive working
   */
  test() {
    print('Sending: \"PING\"');

//    Stream isolateListener = port.asBroadcastStream();
//    isolateListener.first.then((SendPort sp) {
//      sp.send("PING");
//    });
  }

}
