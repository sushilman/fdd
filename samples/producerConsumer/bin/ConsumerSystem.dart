import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:isolate';
import 'dart:io';

/**
 * Not required if deployed via FDD manager (REST or WEB interface)
 */
class PrinterSystem {
  ReceivePort receivePort;

  PrinterSystem() {
    receivePort = new ReceivePort();
    String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/Consumer.dart";

    List<String> workersPaths = ["localhost"];

    IsolateSystem system = new IsolateSystem("mysystem", "ws://localhost:42043/mqs");
    IsolateRef helloPrinter = system.addIsolate("consumer", PrinterSystemWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);
    
  }
}

main() {
  new PrinterSystem();
}
