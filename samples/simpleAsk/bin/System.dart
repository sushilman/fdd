import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:isolate';
import 'dart:io';

/**
 * Not required if deployed via FDD manager (REST or WEB interface)
 */
class System {
  ReceivePort receivePort;

  System() {
    receivePort = new ReceivePort();
    String requesterSourceUri = "${dirname(Platform.script.toString())}/Requester.dart";
    String supplierSourceUri = "${dirname(Platform.script.toString())}/Supplier.dart";

    List<String> requesterWorkersPaths = ["localhost", "localhost"];
    List<String> supplierWorkersPaths = ["localhost", "localhost","localhost", "localhost","localhost", "localhost"];

    IsolateSystem isolateSystem = new IsolateSystem("demosystem", "ws://localhost:42043/mqs");
    IsolateRef requester = isolateSystem.addIsolate("requester", requesterSourceUri, requesterWorkersPaths, Router.RANDOM, hotDeployment:true);
    IsolateRef supplier = isolateSystem.addIsolate("supplier", supplierSourceUri, supplierWorkersPaths, Router.RANDOM, hotDeployment:true);

  }
}

main() {
  new System();
}
