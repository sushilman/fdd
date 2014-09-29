import 'dart:isolate';
import 'dart:io';
import 'package:isolatesystem/worker/Worker.dart';
import 'package:isolatesystem/action/Action.dart';

main(List<String> args, SendPort sendPort) {
  new Downloader(args, sendPort);
}

class Downloader extends Worker {

  Downloader(List<String> args, SendPort sendPort) : super(args, sendPort) {
    print("Downloader started...");
    sendPort.send(["filemonitor", receivePort.sendPort]);
  }

  onReceive(var message) {
    print("Download Isolate: $message");
    if(message is List) {
      switch(message[0]) {
        case Action.DOWNLOAD:
          print("Download Action");
          new HttpClient().getUrl(Uri.parse("http://127.0.0.1:8080/bin/PrinterIsolate.dart"))
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) =>
          response.pipe(new File('/Users/sushil/fdd/helloSystem/bin/packages/isolatesystem/src/.filemonitor/abc.dart').openWrite())).then((_) {
            sendPort.send([Action.DONE]);
          });
          break;
      }
    }
  }
}