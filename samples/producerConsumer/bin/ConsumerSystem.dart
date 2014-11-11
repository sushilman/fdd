import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:isolate';
import 'dart:io';

/**
 * Not required if deployed via FDD manager (REST or WEB interface)
 */
class ConsumerSystem {
  ReceivePort receivePort;

  ConsumerSystem() {
    receivePort = new ReceivePort();
    String sourceUri = "${dirname(Platform.script.toString())}/ConsumerWithLoad.dart";

    List<String> workersPaths = ["localhost", "localhost", "localhost","localhost", "localhost", "localhost"];

    IsolateSystem system = new IsolateSystem("mysystem", "ws://localhost:42043/mqs");
    IsolateRef consumer = system.addIsolate("consumer", sourceUri, workersPaths, Router.RANDOM, hotDeployment:true);
    
  }
}

main() {
  new ConsumerSystem();
}
