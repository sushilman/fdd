import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample multiplier
 */
main(List<String> args, SendPort sendPort) {
  new UserEmulator(args, sendPort);
}

class UserEmulator extends Worker {

  UserEmulator(List<String> args, SendPort sendPort) : super(args, sendPort);

  /**
   * On receive from controller
   */
  void onReceive(var message) {
    print("Result = $message");
  }

  /**
   * Emulate that a user is sending requests periodically
   */
  void onDataFromUser() {
    int rand1 = new Math.Random().nextInt(10);
    int rand2 = new Math.Random().nextInt(20);

    // get multiplied value from this
    // enqueues message to the queue of multiplier
    // by connecting to message queue system

  }
}
