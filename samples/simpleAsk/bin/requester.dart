import 'dart:isolate';
import 'dart:async';
import 'dart:math';
import 'dart:io';

import 'package:isolatesystem/worker/Worker.dart';

import 'AvailableSupplies.dart';

main(List<String> args, SendPort sendPort) {
  new Requester(args, sendPort);
}

class Requester extends Worker {
  static const String SupplierAddress = "demosystem/supplier";
  static const int MAX_REQUESTS = 10000;

  int maxLatency;
  int minLatency;
  int sum;
  int counter;
  DateTime startTime;
  String description = "";

  Requester(List<String> args, SendPort sendPort):super(args, sendPort) {
    startTime = new DateTime.now();
    counter = 0;
    sum = 0;
    //print("Started requester!");
    description = "${args}";
    _sendRequest();
  }

  @override
  onReceive(message) {
    int receivedAt = new DateTime.now().millisecondsSinceEpoch;
    int requestedAt = message['requestedAt'];
    int repliedAt = message['repliedAt'];

    int latency = receivedAt - requestedAt;
    sum +=latency;

    maxLatency = maxLatency == null ? latency : maxLatency;
    minLatency = minLatency == null ? latency : minLatency;

    if(maxLatency < latency) {
      maxLatency = latency;
    }
    if(minLatency > latency) {
      minLatency = latency;
    }

    //print(message['responseMessage']);
    counter++;

    if(counter % 2000 == 0) {
      _writeStats();
    }

    if(counter == MAX_REQUESTS) {
      kill();
    } else {
      _sendRequest();
    }
  }

  _sendRequest() {
    String requestMessage = "";

    int randomNumber = new Random().nextInt(3);
    if(randomNumber == 1) {
      requestMessage = AvailableSupplies.RANDOM_FRUIT;
    } else if (randomNumber == 2) {
      requestMessage = AvailableSupplies.RANDOM_NUMBER;
    } else {
      requestMessage = AvailableSupplies.RANDOM_NAME;
    }

    Map message = {'requestedAt':new DateTime.now().millisecondsSinceEpoch, 'requestMessage':requestMessage};
    ask(message, SupplierAddress);
  }

  @override
  beforeKill() {
    return _writeStats();
  }

  Future _writeStats() {
    String data = """
------------------------------------------------------------------
TITLE: $description
Start Time: $startTime
End Time: ${new DateTime.now()}
Total messages consumed: ${counter}
Average latency: ${sum/counter}
Max Latency: $maxLatency
Min Latency: $minLatency
------------------------------------------------------------------
""";
    return _writeLog(data);
  }

  Future _writeLog(String data) {
    String workerUuid = id.split('/').last;
    File f = new File("log_$description-simpleAsk-requester-$workerUuid.txt");
    var sink = f.openWrite(mode:FileMode.APPEND);
    sink.write(data);
    return sink.close();
  }
}
