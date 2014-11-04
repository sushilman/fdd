import 'dart:isolate';

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
    print("Received At: ${new DateTime.now().millisecondsSinceEpoch}");
    test('Assert Received message',() {
      print ("Received -> $message");
      expect(message, EXPECTED_MESSAGE);
      //expect(message == EXPECTED_MESSAGE, isTrue);
    });
  }
}
