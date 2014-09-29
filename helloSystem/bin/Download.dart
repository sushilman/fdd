import 'dart:io';
import 'dart:isolate';

main() {
  ReceivePort receivePort = new ReceivePort();
  //String name = uri.pathSegments[uri.pathSegments.length - 1];
  Isolate.spawnUri(Uri.parse('Downloader.dart'), [], receivePort.sendPort);
}

