import 'dart:isolate';

import 'SystemBootstrapper.dart';

///Simply start the two isolates
class Activator {
  ReceivePort receivePort;

  Activator(List<String> args) {
    receivePort = new ReceivePort();
    Isolate.spawnUri(Uri.parse("IsolateDeployer.dart"), null, receivePort.sendPort);
    Isolate.spawnUri(Uri.parse("SystemBootstrapper.dart"), args, receivePort.sendPort);
    receivePort.listen(_onReceive);
  }

  void _onReceive(var message){
    // Do nothing
    // this keeps the main thread running
  }
}

void main(List<String> args) {
  if(args.length == 1) {
    new Activator(args);
  } else {
    print("Usage: dart Activator.dart full_websocket_path_of_registry (eg:'ws://localhost:42044/registry')");
  }
}
