import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:unittest/unittest.dart';
import '../lib/IsolateSystem.dart';
import '../lib/IsolateRef.dart';
import '../lib/router/Router.dart';

String EXPECTED_MESSAGE = "Test Message";
const int MESSAGES_COUNT = 20000;
main() {
  group('IsolateSystemTest', () {
    IsolateSystem system;
    IsolateRef testWorker;

    setUp((){

    });

    test('IsolateSystem Creation test', () {
      String systemId = "isolateSystem";
      system = new IsolateSystem(systemId, "ws://localhost:42043/mqs");
      expect(system is IsolateSystem, isTrue);
      expect(system.name == "isolateSystem", isTrue);
    });

    test('IsolateSystem Add Isolate test', () {
      String simpleIsolateUri = "${dirname(Platform.script.toString())}/PerfTestWorker.dart";
      List<String> workersPaths = ["localhost"]; // add more workers separated by comma ["localhost", "localhost"]

      testWorker = system.addIsolate("PerfTestWorker", simpleIsolateUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:false);
      expect(testWorker is IsolateRef, isTrue);
    });

    test('IsolateSystem Message throughput', () {
      int timeStamp;
      for(int counter = 0; counter <= MESSAGES_COUNT; counter++) {
        timeStamp = new DateTime.now().millisecondsSinceEpoch;
        Map message = {'timestamp':timeStamp, 'value':EXPECTED_MESSAGE, 'counter':counter};
        testWorker.sendDirect(message);
      }
    });

    test('IsolateSystem Destruction test', () {
      new Timer(const Duration(seconds:25), () {
        system.killSystem();
      });
    });

    test('Message format test', () {

    });

    tearDown((){

    });
  });
}

checkProgress() {
  //throw new Exception();
}