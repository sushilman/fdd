import 'dart:isolate';
import 'dart:async';
import 'messages/Messages.dart';

/**
 * Just a test isolate
 */
main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort);

  receivePort.listen((message) {
    _onReceive(message, sendport);
  });
}

_onReceive(message, sendport) {
  if(message is String) {
    print ("Printer: $message");
  }
}