import 'dart:isolate';
import 'dart:async';

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort);
  print("Enqueuer Listening...");

  receivePort.listen((msg) {
    _onData(msg, sendport);
  });
}

void _onData(msg, sendport) {
  if(msg is SendPort) {
    print("Send port received !");
  } else {
    print("Enqueue $msg in message_broker_system");
  }
  sendport.send("Hello");
}