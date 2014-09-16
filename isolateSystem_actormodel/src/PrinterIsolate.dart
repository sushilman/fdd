import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'messages/Messages.dart';

/**
 * Just a test isolate
 */
main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort);

  int id = args[0];
  PrinterIsolate printerIsolate = new PrinterIsolate(id);
  receivePort.listen((message) {
    printerIsolate._onReceive(message, sendport, printerIsolate, id);
  });
}


class PrinterIsolate {
  int id;
  int counter = 0;

  PrinterIsolate(this.id);

  _onReceive(message, sendport, printerIsolate, id) {
    if(message is SendPort) {
      //TODO: use this to save sendports of spawned temporary isolates
    } else if(message is String) {
      printerIsolate.outText(message);
    }
  }

  outText(String text) {
    print("Printer: $text");
    print("Doing something... ;) Stuck in infinite loop $id. To prove only 1 message is processed at a time");
    sleep(const Duration(seconds:10));
  }
}