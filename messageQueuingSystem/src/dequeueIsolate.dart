import 'dart:isolate';
import 'dart:async';

main(List<String> args, SendPort sendport) {
  ReceivePort receivePort = new ReceivePort();
  sendport.send(receivePort.sendPort);
  print("Dequeuer Listening...");

  receivePort.listen((msg) {
    _onData(msg, sendport);
  });
}

void _onData(msg, sendport) {
  if(msg is SendPort) {
    print("Send port received !");
  } else {
    print("Dequeue a message from message_broker_system");
  }
  sendport.send("Dequeued message here?");
}