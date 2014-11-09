import 'dart:isolate';

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample isolate for ping pong
 * This worker simply sends the start message
 * which initiates the ping pong between two workers
 */
main(List<String> args, SendPort sendPort) {
  new StartPingPong(args, sendPort);
}

class StartPingPong extends Worker {
  StartPingPong(List<String> args, SendPort sendPort):super(args, sendPort) {

    String pingAddress = "isolateSystem/ping";
    String pongAddress = "isolateSystem/pong";

    send("START", pingAddress, replyTo:pongAddress);
  }

  @override
  onReceive(var message) {
  }
}
