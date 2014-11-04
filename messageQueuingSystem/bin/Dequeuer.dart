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
  SendPort _me;
  int maxMessageBuffer = 1;
  int maxDequeueRequestsBuffered = 1000;
  List<String> dequeueRequestsFrom;

  Map<String, String> bufferMailBox = new Map();

  static const String DEQUEUED = "action.dequeued";
  static const String DEQUEUER = "senderType.dequeuer";

  String host, username, password, topic;
  int connectToPort;

  String subscriptionId;

  int idleCounter = 0;

  Dequeuer(List<String> args, SendPort sendPort) {
    _log("\n\nDequeuer Isolate Spawned !\n\n");
    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    this.sendPort = sendPort;
    dequeueRequestsFrom = new List();

    host = args[0];
    connectToPort = args[1];
    username = args[2];
    password = args[3];
    topic = args[4];
    subscriptionId = "id_$topic";

    sendPort.send({'senderType':DEQUEUER, 'topic':topic, 'payload': _me});

    _initConnection();

    _log("Dequeuer Listening...");

    receivePort.listen((msg) {
      _onReceive(msg);
    });
    _closeIfIdle();
  }

  _onErrorIsolate() {
    print("Caught Exception here, Error in isolate and it is now shutdown");
  }

  _reconnect() {
    _log("Dequeuer: Reconnecting...");
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
    _log("Error: $message \n $detail");
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
    _log("Message from RabbitMQ: $message, HEADERS: $headers");
    var decodedMessage = JSON.decode(message);
    String key = headers["ack"];
    //send message to self to add it to buffer
    _me.send({
        'key':key, 'topic':headers['destination'], 'action':DEQUEUED, 'payload':decodedMessage
    });
  }

  /**
   * Ack after dequeue() is received
   */

  _flushBuffer() {
    if(bufferMailBox.isNotEmpty) {
      _log("\nFlushing buffer");
      print("Size of requests : ${dequeueRequestsFrom.length}");
      bufferMailBox.forEach((key, value) {
        sendPort.send({
            'senderType':DEQUEUER, 'topic':topic, 'payload':value, 'isolateSystemId':dequeueRequestsFrom.removeAt(0)
        });
        client.ack(key);
      });
      bufferMailBox.clear();
    }
  }

  _subscribeMessage(String topic) {
    try {
      client.subscribeString(subscriptionId, topic, _onData, ack:CLIENT_INDIVIDUAL, extraHeaders:{"prefetch-count":"1"});
      _log("Subscribed to $topic");
    } catch(e) {
      _log("May be already Subscribed $e");
      //Already subscribed
    }
  }

  void _onReceive(msg) {
    _log("Dequeue Isolate : $msg");
    idleCounter = 0;
    if (msg is Map) {
      String action = msg['action'];
      switch (action) {
        case Action.DEQUEUE:
          dequeueRequestsFrom.add(msg['isolateSystemId']);
          if (dequeueRequestsFrom.length >= maxDequeueRequestsBuffered) {
            var a = dequeueRequestsFrom.removeAt(0); // removing oldest queue if limit is reached
            print("Removing request as limit is reached : $a");
          }
          _flushBuffer();
          break;
        case DEQUEUED:
          _log("RequestCount: ${dequeueRequestsFrom}");
          bufferMailBox[msg['key']] = msg['payload'];
          if (dequeueRequestsFrom.length > 0) {
            _flushBuffer();
          }
          break;
        default:
          _log("Unknown message -> $msg");
      }
    } else {
      _log("Dequeuer: Bad message: $msg");
    }
  }

  /**
   * Unsubscribes
   * Closes all connections and
   * Kill this isolate if it is idle for a long time
   *
   * It will be respawned, if needed again
   * TODO: implement in MQS
   */
  void _closeIfIdle() {
    bool keepCounting = true;
    new Timer.periodic(const Duration(seconds:1), (Timer t) {
      if(keepCounting) {
        idleCounter++;
        if (idleCounter >= 5) {
          t.cancel();
          _shutDown();
          keepCounting = false;
        }
      }
    });
  }

  _shutDown() {
    print("Shutting Down");
    client.unsubscribe(subscriptionId);
    receivePort.close();
    sendPort.send({'senderType':DEQUEUER, 'payload':null, 'action':"action.killed", 'topic':this.topic});
    throw new Exception("Isolate Shutdown Ugly Hack");
  }

  _log(String text) {
    //print(text);
  }
}
