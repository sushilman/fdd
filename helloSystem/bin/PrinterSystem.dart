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
    String routerUri = "../router/Random.dart";

    String printerWorkerUri = "${dirname(Platform.script.toString())}/PrinterIsolate.dart";

    String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";


    String pingUri = "${dirname(Platform.script.toString())}/Ping.dart";
    String pongUri = "${dirname(Platform.script.toString())}/Pong.dart";

    List<String> workersPaths = ["localhost", "localhost"];

    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");
    IsolateRef helloPrinter = system.addIsolate("helloPrinter", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);
    //IsolateRef helloPrinter2 = system.addIsolate("helloPrinter2", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);

  }
}

main() {
  new PrinterSystem();
}
