import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'messages/Messages.dart';

/**
 * A sample printer isolate
 */
main(List<String> args, SendPort sendPort) {
  PrinterIsolate printerIsolate = new PrinterIsolate(args, sendPort);
}

class PrinterIsolate {
  ReceivePort receivePort;
  SendPort sendPortOfRouter;

  int id;
  int counter = 0;

  PrinterIsolate(List<String> args, this.sendPortOfRouter) {
    id = args[0];
    receivePort = new ReceivePort();
    sendPortOfRouter.send(receivePort.sendPort);

    receivePort.listen((message) {
      _onReceive(message, id);
    });
  }

  _onReceive(message, id) {
    if(message is SendPort) {
      //TODO: use this to save sendports of spawned temporary isolates
    } else if(message is String) {
      outText(message);
    }
  }

  outText(String text) {
    print("Printer: $text");
    print("Doing something... ;) Stuck in infinite loop $id. To prove only 1 message is processed at a time");
    sleep(const Duration(seconds:10));
  }
}