import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample isolate for pong pong
 */
main(List<String> args, SendPort sendPort) {
  new Pong(args, sendPort);
}

class Pong extends Worker {

  Pong(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    } else {
      outTextWithAsk(message);
    }
  }


  outTextWithAsk(var message) {
    if (message['value'].startsWith("PING")) {
      print("## ${message['value']} ${message['count']} ##");
      int count = int.parse(message['count']) + 1;
      ask({'value': "PONG", 'count' : "$count"}, respondTo);
    }
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(var message) {
//    int rand = new Math.Random().nextInt(3);
//    Duration duration = new Duration(seconds: rand);
//    sleep(duration);
    if (message['value'].startsWith("PING")) {
      print("## ${message['value']} ${message['count']} ##");
      int count = int.parse(message['count']) + 1;
      reply({'value': "PONG", 'count' : "$count"}, replyTo:me);
    }
  }
}