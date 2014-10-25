import 'dart:isolate';

///Simply start the two isolates
class Activator {
  ReceivePort receivePort;

  Activator() {
    receivePort = new ReceivePort();
    Isolate.spawnUri(Uri.parse("IsolateDeployer.dart"), null, receivePort.sendPort);
    //Isolate.spawnUri(Uri.parse("SystemBootstrapper.dart"), [], receivePort.sendPort);
    receivePort.listen(_onReceive);
  }

  void _onReceive(var message){
    // Do nothing
    // this keeps the main thread running
  }
}

void main() {
  new Activator();
}
