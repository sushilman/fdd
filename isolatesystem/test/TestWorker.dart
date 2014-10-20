import 'dart:isolate';

import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/worker/Worker.dart';

import 'package:unittest/unittest.dart';
import 'TestIsolateSystem.dart';

main(List<String> args, SendPort sendPort) {
  new TestWorker(args, sendPort);
}

class TestWorker extends Worker {

  TestWorker(List<String> args, SendPort sendPort): super(args, sendPort) {

  }

  @override
  onReceive(var message) {
    print("$message");
    test('Assert Received message',() {
      expect(message == EXPECTED_MESSAGE, isTrue);
    });
  }
}
