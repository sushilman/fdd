import 'dart:isolate';
import 'dart:async';
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';
/**
 * A sample hello isolate
 */
main(List<String> args, SendPort sendPort) {
  Producer producer = new Producer(args, sendPort);
}

class Producer extends Worker {

  static const int MAX_MESSAGES = 500000;
  static const String consumerAddress = "mysystem/consumer";

  Producer(List<String> args, SendPort sendPort) : super(args, sendPort) {
    sendMsgWithDelay();
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
    send("$message$counter", consumerAddress);
  }

  sendMsgWithDelay() {
    int counter = 0;
    String message = "Test #";
    int random = 0;
    new Timer.periodic(new Duration(microseconds:random),(Timer t) {
      random = 100 + new Math.Random().nextInt(1000);
      send("$message${counter++}", consumerAddress);
      print("Created $message #$counter with $random delay");
      if(counter == MAX_MESSAGES) {
        t.cancel();
      }
    });
  }

  kill() {
    print("Say, closing all connections and timers");
  }
}