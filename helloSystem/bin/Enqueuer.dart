import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show sleep;
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
    String message = "Test #";
    new Timer.periodic(const Duration(microseconds:1),(t) {
      send("$message${counter++}", "isolateSystem/helloPrinter");
    });
  }
}