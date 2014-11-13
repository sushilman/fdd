import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample consumer isolate
 */
main(List<String> args, SendPort sendPort) {
  Consumer consumer = new Consumer(args, sendPort);
}

class Consumer extends Worker {
  static const int NO_OF_MESSAGES_TO_CONSUME = 1600000;
  String description = "Test ID ";

  int oldCount = 0;
  int counter = 0;
  Stopwatch stopwatch = new Stopwatch();
  StringBuffer allLog;

  int maxDelayBetweenMessages;
  int minDelayBetweenMessages;

  int totalDelays = 0;
  int startedAt = 0;
  int maxThroughput = 0;

  DateTime startTime;

  Consumer(List<String> args, SendPort sendPort) : super(args, sendPort) {
    description += "${args}";
    allLog = new StringBuffer("\n==Log Separator==\n < $description > \n");
  }

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
    String workerUuid = id.split('/').last;
    File f = new File("log_consumerBenchmark_$description-$workerUuid.txt");
    f.createSync(recursive:true);

    var sink = f.openWrite(mode:FileMode.APPEND);
    sink.write(data);
    return sink.close();
  }
}
