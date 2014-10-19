import 'dart:isolate';

import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/worker/Worker.dart';

main(List<String> args, SendPort sendPort) {
  new TestWorker(args, sendPort);
}

class TestWorker extends Worker {

  TestWorker(List<String> args, SendPort sendPort): super(args, sendPort) {

  }

  @override
  onReceive(var message) {
    print("$message");
  }
}
