import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:isolate';
import 'dart:io';


class EnqueuerSystem {
  ReceivePort receivePort;

  EnqueuerSystem() {
    receivePort = new ReceivePort();
    String PrinterSystemWorkerUri = "${dirname(Platform.script.toString())}/Enqueuer.dart";

    List<String> workersPaths = ["localhost"];

    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");
    IsolateRef enqueuer = system.addIsolate("enqueuer", PrinterSystemWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);
  }
}

main() {
  new EnqueuerSystem();
}
