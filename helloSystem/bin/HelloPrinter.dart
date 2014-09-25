import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'package:isolatesystem/worker/Worker.dart';
import 'package:isolatesystem/action/Action.dart';
import 'dart:math' as Math;
/**
 * A sample printer isolate
 */
main(List<String> args, SendPort sendPort) {
  //print ("Printer Isolate started...");
  HelloPrinter printerIsolate = new HelloPrinter(args, sendPort);
}

class HelloPrinter extends Worker {
  int counter = 0;

  HelloPrinter(List<String> args, SendPort sendPortOfRouter) : super(args, sendPortOfRouter) {
    sendPortOfRouter.send([id, receivePort.sendPort]);
  }

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    } else if(message is String) {
      outText(message);
    }
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(String text) {
    int rand = new Math.Random().nextInt(5);
    Duration duration = new Duration(seconds: rand);
    print("### Hello $id: $text... doing something for $rand seconds");
    sleep(duration);

    //TODO: may be somehow let Worker take care of this DONE action?
    sendPortOfRouter.send([Action.DONE]);
  }
}