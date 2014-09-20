import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'messages/Messages.dart';
import 'worker/Worker.dart';
import 'dart:math' as Math;
/**
 * A sample printer isolate
 */
main(List<String> args, SendPort sendPort) {
  print ("Printer Isolate started...");
  PrinterIsolate printerIsolate = new PrinterIsolate(args, sendPort);
}

class PrinterIsolate extends Worker {
  int counter = 0;

  PrinterIsolate(List<String> args, SendPort sendPortOfRouter) : super(args, sendPortOfRouter);

  @override
  onReceive(message) {
    if(message is SendPort) {
      //TODO: use this to save sendports of spawned temporary isolates
    } else if(message is String) {
      outText(message);
    }
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(String text) {
    int rand = new Math.Random().nextInt(2);
    Duration duration = new Duration(seconds: rand);
    print("Printer $id: $text... doing something for $rand seconds");
    sleep(duration);
  }
}