import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:isolate';
import 'dart:io';


class ProducerSystem {
  ReceivePort receivePort;

  ProducerSystem() {
    receivePort = new ReceivePort();
    String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/Producer.dart";

    List<String> workersPaths = ["localhost"];

    IsolateSystem system = new IsolateSystem("mysystem", "ws://localhost:42043/mqs");
    IsolateRef enqueuer = system.addIsolate("producer", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);
  }
}

main() {
  new ProducerSystem();
}
