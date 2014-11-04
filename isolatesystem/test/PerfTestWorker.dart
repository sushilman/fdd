import 'dart:isolate';

import 'package:isolatesystem/worker/Worker.dart';

import 'package:unittest/unittest.dart';
import 'PerfTestIsolateSystem.dart';

main(List<String> args, SendPort sendPort) {
  new TestWorker(args, sendPort);
}

class TestWorker extends Worker {
  int startTimeStamp;

  TestWorker(List<String> args, SendPort sendPort): super(args, sendPort);

  @override
  onReceive(var message) {
    //print("Received: $message");
    //print("Sent At: ${message['timestamp']}");
    //print("Received At: $timestamp");

    switch(message['counter']) {
      case 0:
        startTimeStamp = message['timestamp'];
        print("Started At: ${startTimeStamp}");
        break;
      case (MESSAGES_COUNT):
        int timestamp = new DateTime.now().millisecondsSinceEpoch;
        print("Ended At: ${timestamp}");
        print("Difference = ${timestamp - startTimeStamp}");
        double average = (timestamp - startTimeStamp) / MESSAGES_COUNT;
        print("Average = ${average}");
        print("Throughput = ${ (1000) / average}");
        break;
    }
    done();
  }
}
