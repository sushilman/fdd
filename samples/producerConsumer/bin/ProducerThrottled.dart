import 'dart:isolate';
import 'dart:io';
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';
/**
 * A sample hello isolate
 */
main(List<String> args, SendPort sendPort) {
  Producer producer = new Producer(args, sendPort);
}

class Producer extends Worker {

  static const int MAX_MESSAGES = 80000;
  static const String consumerAddress = "mysystem/consumer";

  Producer(List<String> args, SendPort sendPort) : super(args, sendPort) {
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
    int random = 0;
    int startTime = new DateTime.now().millisecondsSinceEpoch;
    while(true) {
      random = 500;
      sleep(new Duration(microseconds:random));
      int timestamp = new DateTime.now().millisecondsSinceEpoch;
      Map message = {'createdAt': timestamp, 'message': "Test #${counter++}"};
      send(message, consumerAddress);

      if(counter == MAX_MESSAGES) {
        break;
      }
    }
    int endTime = new DateTime.now().millisecondsSinceEpoch;
    int elapsedTime = endTime - startTime;
    String conclusion = """
----------------------------------------------------------------
Time: ${new DateTime.now()}
Started At: $startTime
Ended At: $endTime
Total Time Consumed: ${elapsedTime} ms
Total Messages Produced: $counter
Throughput: ${(counter / elapsedTime) * 1000} messages per second
----------------------------------------------------------------
""";
    _log(conclusion);

  }

  beforeKill() {
    print("Say, closing all connections and timers");
  }

  _log(var conclusion) {
    File f = new File("log_producer_throttled.txt");
    var sink = f.openWrite(mode:FileMode.APPEND);
    sink.write(conclusion);
    sink.close();
    kill();
  }
}