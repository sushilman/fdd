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
      outTextWithAsk(message);
    }
  }


  outTextWithAsk(var message) {
    if(message == "START") {
      print("** $message");
      ask({'value': "PING", 'count' : "1" }, respondTo);
    } else if (message['value'].startsWith("PONG")) {
      print("**## ${message['value']} ${message['count']} **");
      int count = int.parse(message['count']) + 1;
      ask({'value': "PING", 'count' :  "$count"}, respondTo);
    }
  }

  /**
   * Heavy working function
   * that takes random amount of time
   */
  _calculateFactorial(int n) {
    if(n == 0) {
      return 1;
    }
    int factorial = 1;
    for(int i = 1; i < n; i++) {
      factorial *= i;
    }
    return factorial;
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(var message) {
    //int rand = new Math.Random().nextInt(3);
    //Duration duration = new Duration(seconds: rand);
    //sleep(duration);

    if(message == "START") {
      //ask({'value': "PING", 'count' : "1" }, to:respondTo);
      print("** $message");
      send({'value': "PING", 'count' : "1" }, respondTo, replyTo:me);
    } else if (message['value'].startsWith("PONG")) {
      print("** ${message['value']} ${message['count']} **");
      int count = int.parse(message['count']) + 1;

      reply({'value': "PING", 'count' :  "$count"}, replyTo:me);
    }
    done();
  }
}