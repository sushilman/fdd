import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample consumer isolate
 */
main(List<String> args, SendPort sendPort) {
  Consumer printerIsolate = new Consumer(args, sendPort);
}

class Consumer extends Worker {
  static const int NO_OF_MESSAGES_TO_CONSUME = 80000;
  static const String TEST_DESC = "Test with $NO_OF_MESSAGES_TO_CONSUME messages, 1 MQS, 1 System 1 Consumer, 1 Producer, Starting up simultaneously";
  int oldCount = 0;
  int counter = 0;
  Stopwatch stopwatch = new Stopwatch();
  Consumer(List<String> args, SendPort sendPort) : super(args, sendPort);
  int maxDelayBetweenMessages;
  int minDelayBetweenMessages;

  int totalDelays = 0;
  int startedAt;
  int maxThroughput = 0;

  DateTime startTime;
  StringBuffer allLog = new StringBuffer("\n==Log Separator==\n < $TEST_DESC > \n");


  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    } else {
      outText(message);
    }
  }

  outText(var message) {
    int differenceBetweenTwoMessages = 0;
    if(startTime == null) {
      startTime = new DateTime.now();
      startedAt = startTime.millisecondsSinceEpoch;

      new Timer.periodic(const Duration(seconds:1), (t) {
        int throughput = counter - oldCount;
        if(maxThroughput < throughput) {
          maxThroughput = throughput;
        }
        oldCount = counter;
      });
    }

    if(stopwatch.isRunning) {
      differenceBetweenTwoMessages = stopwatch.elapsedMicroseconds;
      totalDelays += differenceBetweenTwoMessages;
      if(maxDelayBetweenMessages == null) {
        maxDelayBetweenMessages = differenceBetweenTwoMessages;
      } else if(differenceBetweenTwoMessages > maxDelayBetweenMessages) {
        maxDelayBetweenMessages = differenceBetweenTwoMessages;
      }

      if(minDelayBetweenMessages == null) {
        minDelayBetweenMessages = differenceBetweenTwoMessages;
      } else if(differenceBetweenTwoMessages < minDelayBetweenMessages) {
        minDelayBetweenMessages = differenceBetweenTwoMessages;
      }
    }
    int currentTimestamp = new DateTime.now().millisecondsSinceEpoch;
    int createdAt = message['createdAt'];
    int latency = currentTimestamp - createdAt;

    _calculateFactorial(1999);

    stopwatch.start();
    stopwatch.reset();
    if(counter == NO_OF_MESSAGES_TO_CONSUME) {
      kill();
    } else {
      done();
    }
    counter++;
  }

  @override
  beforeKill() {
    return _writeStats();
  }

  Future _writeStats() {
    int endedAt = new DateTime.now().millisecondsSinceEpoch;
    int totalTimeTaken = endedAt - startedAt;
    String data = """
Start Time: $startTime
Started At: $startedAt
Ended At: $endedAt
Total messages consumed: ${counter}
Max Delay between messages: $maxDelayBetweenMessages us
Min Delay between messages: $minDelayBetweenMessages us
Average Delay: ${totalDelays/counter} us
Total Time taken: $totalTimeTaken ms
Average Throughput : ${counter / totalTimeTaken * 1000} per Second
Max Throughput : $maxThroughput per Second
------------------------------------------------------------------
""";
    allLog.write(data);
    return _writeLog(allLog.toString());
  }

  Future _writeLog(String data) {
    File f = new File("log_consumerWithLoadBenchmark.txt");
    var sink = f.openWrite(mode:FileMode.APPEND);
    sink.write(data);
    return sink.close();
  }

  /**
   * Heavy working function
   * that takes random amount of time
   */
  _calculateFactorial(int n) {
    if(n == 0) {
      return 1;
    }
    int factorial = 1;
    for(int i = 1; i < n; i++) {
      factorial *= i;
    }
    return factorial;
  }
}