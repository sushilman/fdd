import 'dart:isolate';
import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';

/**
 * A sample multiplier
 */
main(List<String> args, SendPort sendPort) {
  new Multiplier(args, sendPort);
}

class Multiplier extends Worker {

  Multiplier(List<String> args, SendPort sendPort) : super(args, sendPort);

  void onReceive(var message) {
    int result = message[0] * message[1];
    done(result);
  }
}
