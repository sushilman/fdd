import 'dart:isolate';

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample isolate for ping pong
 * Simply sends the start message
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
