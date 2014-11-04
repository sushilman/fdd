import 'dart:isolate';

import 'package:isolatesystem/worker/Worker.dart';

import 'package:unittest/unittest.dart';
import 'PerfTestIsolateSystem.dart';

main(List<String> args, SendPort sendPort) {
  new TestWorker(args, sendPort);
}

class TestWorker extends Worker {
  int startTimeStamp = 0;

  TestWorker(List<String> args, SendPort sendPort): super(args, sendPort);

  @override
  onReceive(var message) {
    switch(message['counter']) {
      case 0:
        startTimeStamp = int.parse(message['timestamp']);
        print("Started At: ${startTimeStamp}");
        break;
      case (MESSAGES_COUNT - 1):
        int timestamp = new DateTime.now().millisecondsSinceEpoch;
        print("Ended At: ${timestamp}");
        print("Difference = ${timestamp - startTimeStamp}");
        double average = (timestamp - startTimeStamp) / (MESSAGES_COUNT - 1) ;
        print("Average = ${average} ms");
        print("Throughput = ${ (1000) / average}"); // 1000 miliseconds = 1 second
        break;
    }
    done();
  }
}
