import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:unittest/unittest.dart';
import '../lib/IsolateSystem.dart';
import '../lib/IsolateRef.dart';
import '../lib/router/Router.dart';
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
      expect(system.id == "isolateSystem", isTrue);
    });

    test('IsolateSystem Add Isolate test', () {
      String simpleIsolateUri = "${dirname(Platform.script.toString())}/TestWorker.dart";
      List<String> workersPaths = ["localhost"];

      testWorker = system.addIsolate("TestWorker", simpleIsolateUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:false);
      expect(testWorker is IsolateRef, isTrue);
    });

    test('IsolateSystem Send Message test', () {
      testWorker.sendDirect("Test");
    });
//
//    test('IsolateSystem Destruction test', () {
//      system.kill(system);
//    });

    test('Message format test', () {

    });

    tearDown((){

    });
  });
}

checkProgress() {
  //throw new Exception();
}