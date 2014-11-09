import 'dart:isolate';

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample consumer isolate
 */
main(List<String> args, SendPort sendPort) {
  Consumer printerIsolate = new Consumer(args, sendPort);
}

class Consumer extends Worker {
  Consumer(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    } else {
      outText(message);
    }
  }

  outText(var message) {
    print(message);
    done();
  }
}