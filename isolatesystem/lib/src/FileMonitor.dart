import 'dart:io';
import 'dart:isolate';
import 'dart:async';
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

  var oldHash;
  var hash;

  FileMonitor(List<String> args, SendPort sendPort):super(args, sendPort) {
    sendPort.send([id, receivePort.sendPort]);
    startMonitoring(Uri.parse(args[1]));
  }

  onReceive(var message) {
    if(message is SendPort) {

    } else {
      print("FileMonitor: Unhandled message: $message");
    }
  }

  startMonitoring(Uri uri) {
    int seconds = 5;
    Duration duration = new Duration(seconds:seconds);
    print("FileMonitor: Monitoring started for $uri ...");
    new Timer.periodic(duration, (t) {
      _retrieveFile(uri).then((bytes) {
        hash = _calcHash(bytes);
        print("\n\n$oldHash vs $hash\n\n");
        if (oldHash == null) {
          oldHash = hash;
        } else if (hash != null) {
          if (oldHash != hash) {
            oldHash = hash;
            _restartIsolate();
          }
        }
      });
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

  _retrieveFile(Uri uri) {
    return new File.fromUri(uri).readAsBytes();
  }

  _restartIsolate() {
    print("Send Restart command !");
  }
}
