library messageQueuingSystem.dequeueIsolate;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:isolate';
import 'dart:async';

import "Mqs.dart";

/**
 * TODO: There are some ugly hacks that needs to be taken care of !
 *
 *
 * Each Enqueuing and Dequeuing isolate for each TOPIC?
 * if One for all, then Dequeuer will have to subscribe to each topic that is not yet subscribed
 *
 * Each enqueuer/dequeuer for each topic would be better
 * because of ack problem, ack will ack only one message from one of the queue, and buffer will have old message
 * so rabbitmq, will not send another message unless old one is delivered and ack'ed
 *
 * Each isolate for each queue is good solution -> done
 *
 * Oct 12:
 * May be store number of dequeue requests,
 * and once the data arrives from broker system, just dequeue the  number of messages
 *
 */

main(List<String> args, SendPort sendPort) {
  new Dequeuer(args, sendPort);
}

class Dequeuer {

  StompClient client;
  ReceivePort receivePort;
  SendPort sendPort;
  SendPort me;
  int maxMessageBuffer = 1;

  Map<String, String> bufferMailBox = new Map();

  static const String DEQUEUED = "action.dequeued";
  static const String DEQUEUER = "senderType.dequeuer";

  bool bufferWillBeFilled = false;
  bool subscribed = false;
  bool clearBuffer = false;


  Dequeuer(List<String> args, SendPort sendPort) {
    receivePort = new ReceivePort();
    me = receivePort.sendPort;
    this.sendPort = sendPort;

    String host = args[0];
    int port = args[1];
    String username = args[2];
    String password = args[3];
    String topic = args[4];

    sendPort.send({'senderType':DEQUEUER, 'topic':topic, 'message': me});

    connect(host, port:port, login:username, passcode:password).then((StompClient stompClient){
      _handleStompClient(stompClient, topic);
    });

    print("Dequeuer Listening...");

    receivePort.listen((msg) {
      _onReceive(msg);
    });
  }

  _handleStompClient(StompClient stompClient, String topic) {
    client = stompClient;
    _subscribeMessage(Mqs.TOPIC + "/" + topic);
    //_subscribeMessage(Mqs.TOPIC);
  }

  /**
   * Receives message from rabbitmq and keeps in memory buffer but won't be ack'ed yet
   *
   * how to know which topic? headers?
   */

  _onData(Map<String, String> headers, String message) {
    print("Message in buffer: $message, HEADERS: $headers");
    String key = headers["ack"];
    //send message to self to add it to buffer
    me.send({
        'key':key, 'topic':headers['destination'], 'action':DEQUEUED, 'message':message
    });

    //bufferMailBox[headers["ack"]] = message;
  }

  /**
   * Ack after dequeue() is received
   */

  _flushBuffer() {
    bufferMailBox.forEach((key, value) {
      sendPort.send({
          'senderType':DEQUEUER, 'message':value
      });
      client.ack(key);
    });
    bufferMailBox.clear();
  }

  _subscribeMessage(String topic) {
    try {
      client.subscribeString("id_$topic", topic, _onData, ack:CLIENT_INDIVIDUAL);
      print("Subscribed to $topic");
      me.send({'action':Mqs.DEQUEUE});
      subscribed = true;
      bufferWillBeFilled = false;
    } catch(e) {
      print("May be already Subscribed $e");
      //Already subscribed
    }
  }

  void _onReceive(msg) {
    print("Dequeue Isolate : $msg");
    if (msg is SendPort) {
      print("Send port received !");
      //else if message is "dequeue" (from topic?)
    } else if (msg is Map) {
      String action = msg['action'];
      //String topic = Mqs.TOPIC + "/" + msg['topic'];
      switch (action) {
        case Mqs.DEQUEUE:
        // if already subscribed, flush buffer
          if (!bufferWillBeFilled) {
            print("Sending extra dequeue message! $msg");
            //me.send(msg);
            clearBuffer = true;
            bufferWillBeFilled = true;
          }
        
          if (subscribed && bufferMailBox.isNotEmpty) {
            _flushBuffer();
          } else {
            print("\n\n\nBuffer still empty");
          }
          break;
        case DEQUEUED:
          bufferMailBox[msg['key']] = msg['message'];
          if(clearBuffer) {
            _flushBuffer();
            clearBuffer = false;
          }
          break;
        default:
          print("Unknown message -> $msg");
      }
    }
  }
}
