import 'package:isolatesystem/IsolateSystem.dart';
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
    print (printerWorkerUri);

    String helloWorldWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter1.dart";
    //print (helloWorldWorkerUri);

    List<String> workersPaths = ["localhost", "localhost"];
    List<String> workersPaths2 = ["ws://localhost:42042/activator", "ws://localhost:42042/activator"];

    int workersCount = workersPaths.length;
    int workersCount2 = workersPaths2.length;

    //IsolateSystem system = new IsolateSystem(printerWorkerUri, workersCount, workersPaths, routerUri); //"HelloSystem", helloIsolate, new Random(), 5
    IsolateSystem system2 = new IsolateSystem(helloWorldWorkerUri, workersCount2, workersPaths2, routerUri);

    sleep(const Duration(seconds: 5));
    IsolateSystem system3 = new IsolateSystem(printerWorkerUri, workersCount2, workersPaths2, routerUri);
  }
}

main() {
  new HelloWorld();
}