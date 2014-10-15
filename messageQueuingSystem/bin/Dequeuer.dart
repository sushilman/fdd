library messageQueuingSystem.dequeueIsolate;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;

import 'dart:isolate';
import 'dart:async';
import 'dart:convert';

import "Mqs.dart";
import "action/Action.dart";
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
 * Clear all buffers once disconnected from rabbitmq
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
  //int dequeueRequestsCount = 0;
  List<String> dequeueRequestsFrom;

  Map<String, String> bufferMailBox = new Map();

  static const String DEQUEUED = "action.dequeued";
  static const String DEQUEUER = "senderType.dequeuer";

  bool bufferWillBeFilled = false;
  bool subscribed = false;
  bool clearBuffer = false;

  String host, username, password, topic;
  int connectToPort;

  Dequeuer(List<String> args, SendPort sendPort) {
    _out("\n\nDequeuer Isolate Spawned !\n\n");
    receivePort = new ReceivePort();
    me = receivePort.sendPort;
    this.sendPort = sendPort;
    dequeueRequestsFrom = new List();

    host = args[0];
    connectToPort = args[1];
    username = args[2];
    password = args[3];
    topic = args[4];

    sendPort.send({'senderType':DEQUEUER, 'topic':topic, 'message': me});

    _initConnection();

    _out("Dequeuer Listening...");

    receivePort.listen((msg) {
      _onReceive(msg);
    });
  }

  _reconnect() {
    _out("Dequeuer: Reconnecting...");
    new Timer(new Duration(seconds:3), () {
      _initConnection();
    });
  }

  void _onDisconnect(StompClient client) {
    bufferMailBox.clear();
    _reconnect();
  }

  void _onError([StompClient client, String message, String detail, Map<String, String> headers]) {
    bufferMailBox.clear();
    _out("Error: $message \n $detail");
    _reconnect();
  }

  void _initConnection() {
    connect(host, port:connectToPort, login:username, passcode:password, onError:_onError, onDisconnect:_onDisconnect).then((StompClient stompClient) {
      _handleStompClient(stompClient, topic);
    }, onError:_onError);
  }

  _handleStompClient(StompClient stompClient, String topic) {
    client = stompClient;
    _subscribeMessage(Mqs.TOPIC + "/" + topic);
  }

  /**
   * Receives message from rabbitmq and keeps in memory buffer but won't be ack'ed yet
   *
   * how to know which topic? headers?
   */

  _onData(Map<String, String> headers, String message) {
    _out("Message from RabbitMQ: $message, HEADERS: $headers");
    var decodedMessage = JSON.decode(message);
    String key = headers["ack"];
    //send message to self to add it to buffer
    me.send({
        'key':key, 'topic':headers['destination'], 'action':DEQUEUED, 'message':decodedMessage
    });
  }

  /**
   * Ack after dequeue() is received
   */

  _flushBuffer() {
    if(bufferMailBox.isNotEmpty) {
      _out("\nFlushing buffer");
      bufferMailBox.forEach((key, value) {
        sendPort.send({
            'senderType':DEQUEUER, 'topic':topic, 'message':value, 'socket':dequeueRequestsFrom.removeAt(0)
        });
        client.ack(key);
        //dequeueRequestsCount--;
      });
      bufferMailBox.clear();
    }
  }

  _subscribeMessage(String topic) {
    try {
      client.subscribeString("id_$topic", topic, _onData, ack:CLIENT_INDIVIDUAL);
      _out("Subscribed to $topic");
      //me.send({'action':Mqs.DEQUEUE});
      subscribed = true;
      bufferWillBeFilled = false;
    } catch(e) {
      _out("May be already Subscribed $e");
      //Already subscribed
    }
  }

  void _onReceive(msg) {
    _out("Dequeue Isolate : $msg");
    if (msg is Map) {
      String action = msg['action'];
      switch (action) {
        case Action.DEQUEUE:
          //dequeueRequestsCount++;
          dequeueRequestsFrom.add(msg['socket']);
          _flushBuffer();

          break;
        case DEQUEUED:
          _out("RequestCount: ${dequeueRequestsFrom}");
          bufferMailBox[msg['key']] = msg['message'];
          if(dequeueRequestsFrom.length > 0) {
            _flushBuffer();
          }
          break;
        default:
          _out("Unknown message -> $msg");
      }
    } else {
      _out("Dequeuer: Bad message: $msg");
    }
  }

  _out(String text) {
    //print(text);
  }
}
