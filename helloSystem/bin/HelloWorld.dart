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
    //print (helloWorldWorkerUri);


    String pingUri = "${dirname(Platform.script.toString())}/Ping.dart";
    String pongUri = "${dirname(Platform.script.toString())}/Pong.dart";

    List<String> workersPaths = ["localhost", "localhost", "localhost", "localhost", "localhost", "localhost"];
    //List<String> workersPaths = ["ws://192.168.2.69:42042/activator", "ws://192.168.2.69:42042/activator"];
    //List<String> workersPaths = ["ws://localhost:42042/activator", "ws://localhost:42042/activator"];

    //int workersCount = workersPaths.length;
    //int workersCount2 = workersPaths2.length;


    IsolateSystem system = new IsolateSystem("isolateSystem", "ws://localhost:42043/mqs");

    //system.addIsolate("Multiplier", multiplierWorkerUri, workersPaths, Router.RANDOM,  args:"test");

    //IsolateRef helloPrinter = system.addIsolate("helloPrinter", helloWorldWorkerUri, workersPaths, Router.ROUND_ROBIN, hotDeployment:true);
    //helloPrinter.send("This is a very confidential message This is a very confidential message This is a very confidential message #", replyTo:helloPrinter);

//    Duration duration = new Duration(seconds:2);
//    sleep(duration);
    //helloPrinter.send("Print me! 1",replyTo: helloPrinter);
//    helloPrinter.send("Print me! 2",replyTo: helloPrinter);
//    helloPrinter.send("Print me! 3",replyTo: helloPrinter);
//    helloPrinter.send("XYZPrint me! 4");
//    helloPrinter.send("Print me! 5");

    //IsolateSystem system2 = new IsolateSystem(helloWorldWorkerUri, workersCount2, workersPaths2, routerUri);

    //sleep(const Duration(seconds: 5));
    //IsolateSystem system3 = new IsolateSystem(printerWorkerUri, workersCount2, workersPaths2, routerUri);


    //IsolateRef ping = system.addIsolate("ping", pingUri, workersPaths, Router.RANDOM, hotDeployment:true);
    //IsolateRef pong = system.addIsolate("pong", pongUri, workersPaths, Router.RANDOM, hotDeployment:true);

    //ping.send("START", replyTo: pong);

  }
}

main() {
  new HelloWorld();
}
