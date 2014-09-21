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

    String workerUri = "${dirname(Platform.script.toString())}/PrinterIsolate.dart";
    print (workerUri);
    int workersCount = 1;
    IsolateSystem system = new IsolateSystem(workerUri, workersCount, routerUri); //"HelloSystem", helloIsolate, new Random(), 5
  }
}

main() {
  new HelloWorld();
}
