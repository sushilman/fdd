import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample printer isolate
 */
main(List<String> args, SendPort sendPort) {
  //print ("Printer Isolate started...");
  PrinterIsolate printerIsolate = new PrinterIsolate(args, sendPort);
}

class PrinterIsolate extends Worker {
  int counter = 0;

  PrinterIsolate(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  onReceive(message) {
    if(message is SendPort) {
      //TODO: use this to save sendports of spawned temporary isolates
    } else {
      outText(message);
    }
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(String text) {
    int rand = new Math.Random().nextInt(5);
    //int rand = 1;
    Duration duration = new Duration(seconds: rand);
    print("***!!! MY Printer $id: $text... doing something for $rand seconds");
    sleep(duration);
    done();
  }
}