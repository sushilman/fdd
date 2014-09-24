import 'dart:isolate';
/**
 * A simple isolate
 * which on receiving "hello" message
 * replies "Hello there"
 * otherwise replies "Didn't understand that !"
 */

main(SendPort sendport) {
  int counter = 0;
  ReceivePort port = new ReceivePort();
  sendport.send(port.sendPort);
  print("Listening...");

  port.listen((msg) {
    if(msg is SendPort) {
      msg.send(counter++);
      print("Send port");
    }
    sendport.send(helloWorld(msg));
  });
}

String helloWorld(String message) {
  print("Message received: $message");
  switch(message) {
      case "PING":
        print("Isolate: PONG");
        return "PONG";
        break;
      default:
        print("Didn't understatnd");
        return "Didn't understand that !";
    }
}
