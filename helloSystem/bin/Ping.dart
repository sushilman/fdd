import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample isolate for ping pong
 */
main(List<String> args, SendPort sendPort) {
  new Ping(args, sendPort);
}

class Ping extends Worker {
  Ping(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    } else {
      outText(message);
    }
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(var message) {
    int rand = new Math.Random().nextInt(3);
    Duration duration = new Duration(seconds: rand);
    //sleep(duration);

    if(message == "START") {
      reply({'value': "PING", 'count' : "1" });
    } else if (message['value'].startsWith("PONG")) {
      print("*** ${message['value']} ${message['count']} **");
      int count = int.parse(message['count']) + 1;
      reply({'value': "PING", 'count' :  "$count"});
    }
  }
}