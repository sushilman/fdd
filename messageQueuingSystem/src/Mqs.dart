import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "dart:isolate";
import "dart:async";

class Mqs {

  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;
  static const String GUEST_LOGIN = "guest";
  static const String GUEST_PASSWORD = "guest";

  ReceivePort receivePortEnqueue;
  ReceivePort receivePortDequeue;
  Uri enqueueIsolate = Uri.parse("enqueueIsolate.dart");
  Uri dequeueIsolate = Uri.parse("dequeueIsolate.dart");
  SendPort enqueueSendPort;
  SendPort dequeueSendPort;

  StompClient client;

  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:GUEST_LOGIN, password:GUEST_PASSWORD}) {
    receivePortEnqueue = new ReceivePort();
    receivePortEnqueue.listen(_onReceiveFromEnqueueIsolate);

    receivePortDequeue = new ReceivePort();
    receivePortDequeue.listen(_onReceiveFromDequeueIsolate);
    connect(host, port:port, login:username, passcode:password).then(_handleStompClient);
  }


  _handleStompClient(StompClient client) {
    this.client = client;
    client.subscribeString("id1", "/queue/test", _onReceive);
    print("Starting up enqueuer and dequeuer...");
    _startEnqueuerIsolate(client);
    _startDequeuerIsolate(client);
  }

  _onReceive(Map<String, String> headers, String message) {
      print("Receive $message, $headers");
  }

  _startEnqueuerIsolate(StompClient client) {
    Isolate.spawnUri(enqueueIsolate, [], receivePortEnqueue.sendPort);
  }

  _startDequeuerIsolate(StompClient client) {
    Isolate.spawnUri(dequeueIsolate, [], receivePortDequeue.sendPort);
  }

  _onReceiveFromEnqueueIsolate(message) {
    if(enqueueSendPort == null) {
      enqueueSendPort = message;
      print("Sendport to enq isolate $message" + enqueueSendPort.hashCode.toString());
    } else {
      print ("Received response from isolate: $message");
    }
    print ("Response : $message");
  }

  _onReceiveFromDequeueIsolate(message) {
    if(dequeueSendPort == null) {
      dequeueSendPort = message;
      print("Sendport to deq isolate $message" + dequeueSendPort.hashCode.toString());
    } else {
      print ("Received response from isolate: $message");
    }
    print ("Response : $message");
  }

  enqueue(String message) {
    // receive message from caller of this function
    // enqueue message
  }

  String dequeue() {
    // listen to message from isolate and dequeue
    return null;
  }

  /// returns true if successfully enqueued
  bool enqueueMessage(String topic, String message, {Map<String, String> headers}) {
      if(client != null) {
        client.sendString(topic, message, headers:headers);
        print("Returning true...");
        return true;
      }
    return false;
  }

  _init() {
    connect("127.0.0.1", port:61613, login:"guest", passcode:"guest").then((StompClient client) {
      client.subscribeString("id1", "/queue/test",
          (Map<String, String> headers, String message) {
        print ("Receive $message $headers");
      });

      Map<String, String> sendHeaders = new Map();
      sendHeaders["reply-to"] = "/temp-queue/foo";
      client.sendString("/queue/test", "Hi, Stomp", headers:sendHeaders);
    });
  }
}