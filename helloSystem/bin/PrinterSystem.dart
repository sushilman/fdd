import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:async';
import 'dart:isolate';
import 'dart:io';


class PrinterSystem {
  ReceivePort receivePort;

  PrinterSystem() {
    receivePort = new ReceivePort();
    String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";

    List<String> workersPaths = ["localhost"];

    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");
    IsolateRef helloPrinter = system.addIsolate("helloPrinter", PrinterSystemWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);
    
  }
}

main() {
  new PrinterSystem();
}
