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
    String printerWorkerUri = "${dirname(Platform.script.toString())}/PrinterIsolate.dart";
    String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";

    List<String> workersPaths = ["localhost", "ws://localhost:42042/activator"];

    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");
    IsolateRef helloPrinter = system.addIsolate("helloPrinter5", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);
    //IsolateRef helloPrinter2 = system.addIsolate("helloPrinter2", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);

  }
}

main() {
  new PrinterSystem();
}
