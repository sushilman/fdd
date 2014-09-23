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

    String helloWorldWorkerUri = "${dirname(Platform.script.toString())}/HelloPrinter.dart";
    print (helloWorldWorkerUri);

    //List<String> workersPaths = ["localhost", "localhost"];
    List<String> workersPaths = ["ws://localhost:42042/activator", "ws://localhost:42042/activator"];

    int workersCount = workersPaths.length;

    IsolateSystem system = new IsolateSystem(printerWorkerUri, workersCount, workersPaths, routerUri); //"HelloSystem", helloIsolate, new Random(), 5
    IsolateSystem system2 = new IsolateSystem(helloWorldWorkerUri, workersCount, workersPaths, routerUri);
  }
}

main() {
  new HelloWorld();
}
