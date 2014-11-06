import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:async';
import 'dart:isolate';
import 'dart:io';

/**
 * A Ping pong test system
 */

class PingPongSystem {
  ReceivePort receivePort;

  PingPongSystem() {
    receivePort = new ReceivePort();

    String printerWorkerUri = "${dirname(Platform.script.toString())}/PrinterIsolate.dart";

    String PingPongSystemWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";

    String pingUri = "${dirname(Platform.script.toString())}/Ping.dart";
    String pongUri = "${dirname(Platform.script.toString())}/Pong.dart";

    List<String> pingWorkersPaths = ["localhost"];
    List<String> pongWorkersPaths = ["localhost"];

    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");
    IsolateRef ping = system.addIsolate("ping", pingUri, pingWorkersPaths, Router.ROUND_ROBIN, hotDeployment:false);
    IsolateRef pong = system.addIsolate("pong", pongUri, pongWorkersPaths, Router.ROUND_ROBIN, hotDeployment:true);

    // Bypasses the message queuing system for this particular first message
    ping.sendDirect("START", replyTo: pong);
  }
}

main() {
  new PingPongSystem();
}
