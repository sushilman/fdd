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

    String PrinterSystemWorkerUri = "http://192.168.2.4/helloSystem/HelloPrinter.dart";
    //String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";

    List<String> workersPaths = ["localhost", "ws://192.168.2.69:42042/activator"];

    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");
    IsolateRef helloPrinter = system.addIsolate("helloPrinter5", PrinterSystemWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);
    //IsolateRef helloPrinter2 = system.addIsolate("helloPrinter2", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);

  }
}

main() {
  new PrinterSystem();
}
