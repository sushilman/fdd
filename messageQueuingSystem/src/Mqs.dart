import "dart:isolate";
import "dart:async";

/**
 * TODO:
 * 1. Receive message in the system
 *   => Receive message via ? -> websocket?
 */
class Mqs {

  static const String LOCALHOST = "127.0.0.1";
  static const int RABBITMQ_DEFAULT_PORT = 61613;
  static const String GUEST_LOGIN = "guest";
  static const String GUEST_PASSWORD = "guest";

  static const String TOPIC = "/queue/test";
  static Map<String, String> HEADERS = null;//{'reply-to' : '/queue/test'};

  ReceivePort receivePortEnqueue;
  ReceivePort receivePortDequeue;
  Uri enqueueIsolate = Uri.parse("enqueueIsolate.dart");
  Uri dequeueIsolate = Uri.parse("dequeueIsolate.dart");
  SendPort enqueueSendPort;
  SendPort dequeueSendPort;
//
//  StompClient client;

  Mqs({host:LOCALHOST, port:RABBITMQ_DEFAULT_PORT, username:GUEST_LOGIN, password:GUEST_PASSWORD}) {
    receivePortEnqueue = new ReceivePort();
    receivePortEnqueue.listen(_onReceiveFromEnqueueIsolate);
    print("Starting up enqueuer and dequeuer...");
    List<String> args = [host, port, username, password];
    _startEnqueuerIsolate(args);

    receivePortDequeue = new ReceivePort();
    receivePortDequeue.listen(_onReceiveFromDequeueIsolate);
    _startDequeuerIsolate(args);
  }

  _startEnqueuerIsolate(List<String> args) {
    Isolate.spawnUri(enqueueIsolate, args, receivePortEnqueue.sendPort);
  }

  _startDequeuerIsolate(List<String> args) {
    Isolate.spawnUri(dequeueIsolate, args, receivePortDequeue.sendPort);
  }

  _onReceiveFromEnqueueIsolate(message) {
    if(enqueueSendPort == null) {
      enqueueSendPort = message;
      print("Sendport to enq isolate $message" + enqueueSendPort.hashCode.toString());
    } else {
      print ("Received response from isolate: $message");
    }
    print ("Enqueue Response : $message");
  }

  _onReceiveFromDequeueIsolate(message) {
    if(dequeueSendPort == null) {
      dequeueSendPort = message;
      print("Sendport to deq isolate $message" + dequeueSendPort.hashCode.toString());
    } else {
      print ("Received response from dequeue isolate: $message");
    }
    print ("Dequeued : $message");
  }

  enqueue(String message) {
    enqueueSendPort.send(message);
  }

  /**
   * Will be asynchronous
   */
  String dequeue() {
    dequeueSendPort.send("Dequeue a message");
  }
}

/**
 * Start the Message Queuing System
 */
main() {
  Mqs mqs = new Mqs(host:"127.0.0.1", port:61613);
  int counter = 0;
  new Timer.periodic(const Duration(seconds:0.1), (t) {
    //mqs.enqueue("Message ${counter++}");
  });
  new Timer.periodic(const Duration(seconds:0.1), (t) {
    mqs.dequeue();
  });

}
