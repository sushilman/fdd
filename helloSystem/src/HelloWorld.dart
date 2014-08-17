import 'package:isolatesystem/IsolateSystem.dart';
import 'dart:isolate';

class HelloWorld {
  ReceivePort receivePort;

  HelloWorld() {
    receivePort = new ReceivePort();
    Uri helloIsolate = new Uri.file("HelloIsolate.dart");
    IsolateSystem system = new IsolateSystem("HelloSystem", helloIsolate, new Random(), 5);

  }
}

main() {
  new HelloWorld();
}
