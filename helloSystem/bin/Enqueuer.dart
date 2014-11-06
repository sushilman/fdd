import 'dart:isolate';
import 'dart:async';
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';
/**
 * A sample hello isolate
 */
main(List<String> args, SendPort sendPort) {
  HelloPrinter printerIsolate = new HelloPrinter(args, sendPort);
}

class HelloPrinter extends Worker {
  HelloPrinter(List<String> args, SendPort sendPort) : super(args, sendPort) {
    sendMsgUsingTimer();
  }

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    }
  }

  sendMsg() {
    int counter = 0;
    String message = "Test #";
    send("$message$counter", "isolateSystem/helloPrinter");
  }

  sendMsgUsingTimer() {
    int counter = 0;
    String message = "Test !";
    int random = 1000000 + new Math.Random().nextInt(100);
    new Timer.periodic(new Duration(microseconds:random),(Timer t) {
      send("$message${counter++}", "isolateSystem/helloPrinter");
      print("Created $message#$counter");
      if(counter > 500000) {
        t.cancel();
      }
    });
  }

  kill() {
    print("Say, closing all connections and timers");
  }
}