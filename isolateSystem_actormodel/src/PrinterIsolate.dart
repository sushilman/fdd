import 'dart:isolate';
import 'dart:async';
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
    _onReceive(message, sendport, printerIsolate, id);
  });
}

_onReceive(message, sendport, printerIsolate, id) {
  if(message is SendPort) {
    //TODO: use this to save sendports of spawned temporary isolates
  } else if(message is String) {
    printerIsolate.outText(message);

    new Timer.periodic(const Duration(seconds: 0.5), (t) {
      print ("Printer ${id}: $message ");
    });
  }
}

class PrinterIsolate {
  int id;
  int counter = 0;
  //TODO: temporary uuid to recognize which isolate is getting the message
  // we can simply pass the serialNumber to this isolate from router
  int uuid = new DateTime.now().millisecondsSinceEpoch;

  PrinterIsolate(this.id);

  outText(String text) {
    print("Doing something... ;) Stuck in infinite loop $id. To prove only 1 message is processed at a time");
    while(true);
  }
}