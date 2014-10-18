import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import 'package:isolatesystem/IsolateRef.dart';
import "package:path/path.dart" show dirname;

import 'dart:async';
import 'dart:isolate';
import 'dart:io';


class HelloWorld {
  ReceivePort receivePort;

  HelloWorld() {
    receivePort = new ReceivePort();
    //Uri helloIsolate = new Uri.file("PrinterIsolate.dart");
    String routerUri = "../router/Random.dart";

    String printerWorkerUri = "${dirname(Platform.script.toString())}/PrinterIsolate.dart";
    //String printerWorkerUri = "http://127.0.0.1:8080/bin/PrinterIsolate.dart";
    //print (printerWorkerUri);

    String helloWorldWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";
    //String helloWorldWorkerUri = "http://192.168.2.2:8080/HelloPrinter.dart";
    //print (helloWorldWorkerUri);


    String pingUri = "${dirname(Platform.script.toString())}/Ping.dart";
    String pongUri = "${dirname(Platform.script.toString())}/Pong.dart";

    List<String> pingWorkersPaths = ["localhost", "localhost"];
    List<String> pongWorkersPaths = ["localhost"];
    //List<String> workersPaths = ["ws://192.168.2.69:42042/activator", "ws://192.168.2.69:42042/activator"];
    //List<String> workersPaths = ["ws://localhost:42042/activator", "ws://192.168.2.69:42042/activator"];

    //int workersCount = workersPaths.length;
    //int workersCount2 = workersPaths2.length;


    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");

    //system.addIsolate("Multiplier", multiplierWorkerUri, workersPaths, Router.RANDOM,  args:"test");

    //IsolateRef helloPrinter = system.addIsolate("helloPrinter", helloWorldWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);
    //IsolateRef helloPrinter2 = system.addIsolate("helloPrinter2", helloWorldWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);


    IsolateRef ping = system.addIsolate("ping", pingUri, pingWorkersPaths, Router.RANDOM, hotDeployment:false);
    IsolateRef pong = system.addIsolate("pong", pongUri, pongWorkersPaths, Router.RANDOM, hotDeployment:false);

    ping.sendDirect("START", replyTo: pong);

  }
}

main() {
  new HelloWorld();
}
