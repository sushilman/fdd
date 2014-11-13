import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:convert';

import 'package:isolatesystem/worker/Worker.dart';
/**
 * A sample hello isolate
 */
main(List<String> args, SendPort sendPort) {
  Producer producer = new Producer(args, sendPort);
}

class Producer extends Worker {

  static const int MAX_MESSAGES = 640000;
  static const String consumerAddress = "mysystem/consumer";

  static const String TextBytes64   = "0123456701234567012345670123456701234567012345670123456701234567";

  static const String Message64Bytes = "012345670123456701234567";
  static const String Message128Bytes  = "$Message64Bytes$TextBytes64";
  static const String Message256Bytes  = "$Message128Bytes$TextBytes64$TextBytes64";
  static const String Message512Bytes  = "$Message256Bytes$TextBytes64$TextBytes64$TextBytes64$TextBytes64";
  static const String Message1024Bytes = "$Message512Bytes$TextBytes64$TextBytes64$TextBytes64$TextBytes64$TextBytes64$TextBytes64$TextBytes64$TextBytes64";


  StringBuffer data = new StringBuffer();
  String description = "";

  Producer(List<String> args, SendPort sendPort) : super(args, sendPort) {
    description += "${args}";
    sendMsgWithDelay();
  }

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    }
  }

  sendMsgWithDelay() {
    int counter = 0;
    int oldCount = 0;

    int startTime = new DateTime.now().millisecondsSinceEpoch;

    new Timer.periodic(const Duration(seconds:1), (t) {
      var throughPutPerSecond = "${(counter - oldCount)}";
      oldCount = counter;
      data.write("[${new DateTime.now()}] Throughput per second: ${throughPutPerSecond.toString()}");
    });

    while(true) {
      int timestamp = new DateTime.now().millisecondsSinceEpoch;
      Map message = {'createdAt': timestamp, 'message': Message64Bytes};
      //print(JSON.encode(message).length);
      //sleep(const Duration(microseconds:500));
      send(message, consumerAddress);
      counter++;
      if(counter >= MAX_MESSAGES) {
        break;
      }
    }
    int endTime = new DateTime.now().millisecondsSinceEpoch;
    int elapsedTime = endTime - startTime;
    data.write("""
----------------------------------------------------------------
Time: ${new DateTime.now()}
Started At: $startTime
Ended At: $endTime
Total Time Consumed: ${elapsedTime} ms
Total Messages Produced: $counter
Throughput: ${(counter / elapsedTime) * 1000} messages per second
----------------------------------------------------------------
""");

    _log(data.toString());
  }

  _log(var data) {
    String workerUuid = id.split('/').last;
    File f = new File("log_$description-producer-$workerUuid.txt");
    var sink = f.openWrite(mode:FileMode.APPEND);
    sink.write(data);
    sink.close();
  }
}