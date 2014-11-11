import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:isolate';
import 'dart:io';

/**
 * Not required if deployed via FDD manager (REST or WEB interface)
 */
class ProducerConsumerSystem {
  ReceivePort receivePort;

  ProducerConsumerSystem() {
    receivePort = new ReceivePort();
    String ConsumerWorkerUri= "${dirname(Platform.script.toString())}/ConsumerBenchmark.dart";
    String ProducerWorkerUri = "${dirname(Platform.script.toString())}/Producer.dart";

    List<String> workersPaths = ["localhost"];

    IsolateSystem system = new IsolateSystem("mysystem", "ws://localhost:42043/mqs");
    IsolateRef consumer = system.addIsolate("consumer", ConsumerWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);
    IsolateRef producer = system.addIsolate("producer", ProducerWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);

  }
}

main() {
  new ProducerConsumerSystem();
}
