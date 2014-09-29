import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:math' as Math;
import 'package:path/path.dart';
import '../worker/Worker.dart';
import '../action/Action.dart';
import 'package:crypto/crypto.dart';

/**
 * For: HOT DEPLOYMENT CONCEPT
 * Idea is to have a monitor running for each isolate system
 * and each isolate system can have it enabled or disabled
 */

main(List<String> args, SendPort sendPort) {
  new FileMonitor(args, sendPort);
}

class FileMonitor extends Worker {

  FileMonitor(List<String> args, SendPort sendPort):super(args, sendPort) {
    sendPort.send([id, receivePort.sendPort]);
    startMonitoring(Uri.parse(args[1]));
  }

  onReceive(var message) {
    print("FileMonitor: $message");
    if(message is SendPort) {

    } else {
      print("FileMonitor: Unhandled message: $message");
    }
  }

  startMonitoring(Uri uri) {
    int seconds = 5;
    var oldHash;
    var hash;

    Duration duration = new Duration(seconds:seconds);
    new Timer.periodic(duration, (t) {
      new HttpClient().getUrl(Uri.parse("http://127.0.0.1:8080/bin/PrinterIsolate.dart"))
      .then((HttpClientRequest request) => request.close())
      .then((HttpClientResponse response) => response.listen((value) {
        List<int> fileContent = new List<int>();
        fileContent.addAll(value);
        hash = _calcHash(fileContent);
        print("Hash:" + hash);
        if (oldHash == null) {
          oldHash = hash;
        } else if (hash != null) {
          if (oldHash != hash) {
            oldHash = hash;
            _restartIsolate();
          }
        }
      }));
    });
  }

  _calcHash(bytes) {
    MD5 md5 = new MD5();
    md5.add(bytes);
    var hash = md5.close();
    StringBuffer sb = new StringBuffer();
    for(int i = 0; i<hash.length; i++) {
      var val = hash[i].toRadixString(16);
      sb.write(val.length == 1 ? "0$val" : val);
    }
    return sb.toString();
  }

  String _randomString() {
    String alphabets = "abcdefghijklmnopqrstuvwxyz0123456789";
    Math.Random random = new Math.Random();
    int length = 3 + random.nextInt(9);
    StringBuffer filename = new StringBuffer();
    for(int i = 0; i<length; i++) {
      filename.write(alphabets[random.nextInt(alphabets.length)]);
    }
    return filename.toString();
  }

  _restartIsolate() {
    sendPort.send([Action.RESTART_ALL]);
    print("Send Restart command !");
  }
}
