import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/router/Router.dart';
import "package:path/path.dart" show dirname;
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

    //List<String> workersPaths = ["localhost/p1", "localhost/p2"];
    //List<String> workersPaths = ["ws://192.168.2.69:42042/activator", "ws://192.168.2.69:42042/activator"];
    List<String> workersPaths = ["ws://localhost:42042/activator", "ws://localhost:42042/activator"];

    int workersCount = workersPaths.length;
    //int workersCount2 = workersPaths2.length;

    //IsolateSystem system = new IsolateSystem(printerWorkerUri, workersCount, workersPaths, routerUri, hotDeployment:true); //"HelloSystem", helloIsolate, new Random(), 5

    IsolateSystem system = new IsolateSystem("mySystem");
    system.addIsolate("simplePrinter", printerWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);
    system.addIsolate("helloPrinter", helloWorldWorkerUri, workersPaths, Router.RANDOM, hotDeployment:true);
    //IsolateSystem system2 = new IsolateSystem(helloWorldWorkerUri, workersCount2, workersPaths2, routerUri);

    //sleep(const Duration(seconds: 5));
    //IsolateSystem system3 = new IsolateSystem(printerWorkerUri, workersCount2, workersPaths2, routerUri);
  }
}

main() {
  new HelloWorld();
}
