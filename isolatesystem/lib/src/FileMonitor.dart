import 'dart:io';
import 'dart:isolate';
import 'dart:async';
import 'dart:math' as Math;

import 'package:path/path.dart';
import 'package:crypto/crypto.dart';

import '../worker/Worker.dart';
import '../action/Action.dart';
import '../message/MessageUtil.dart';
import '../message/SenderType.dart';

/**
 * For: HOT DEPLOYMENT CONCEPT
 * Idea is to have a monitor running for each isolate group
 * and each isolate group can have it enabled or disabled
 */

main(List<String> args, SendPort sendPort) {
  new FileMonitor(args, sendPort);
}

class FileMonitor extends Worker {
  String routerId;

  FileMonitor(List<String> args, SendPort sendPort) : super.withoutReadyMessage(args, sendPort) {
    sendPort.send(MessageUtil.create(SenderType.FILE_MONITOR, id, Action.CREATED, receivePort.sendPort));
    routerId = args[0];
    startMonitoring(Uri.parse(args[1]));
  }

  onReceive(var message) {
    //print("FileMonitor: $message");
    if(message is SendPort) {

    } else {
      print("FileMonitor: Unhandled message: $message");
    }
  }

  startMonitoring(Uri uri) {
    int seconds = 2;
    var oldHash;
    var hash;
    print ("Monitoring started for uri $uri");
    Duration duration = new Duration(seconds:seconds);
    if(uri.toString().startsWith("http://")
    || uri.toString().startsWith("https://")
    || uri.toString().startsWith("ftp://")) {
      new Timer.periodic(duration, (t) {
        new HttpClient().getUrl(uri) //Uri.parse("http://127.0.0.1:8080/bin/PrinterIsolate.dart")
        .then((HttpClientRequest request) => request.close())
        .then((HttpClientResponse response) => response.listen((value) {
          List<int> fileContent = new List<int>();
          fileContent.addAll(value);
          hash = _calcHash(fileContent);
          //print("Hash:" + hash);
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
    } else {
      new Timer.periodic(duration, (t) {
        new File.fromUri(uri).readAsBytes().then((bytes) {
          List<int> fileContent = new List<int>();
          fileContent.addAll(bytes);
          hash = _calcHash(fileContent);
          //print("Hash:" + hash);
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

  _restartIsolate() {
    sendPort.send(MessageUtil.create(SenderType.FILE_MONITOR, id, Action.RESTART, [routerId]));
    print("Restart command issued !");
  }
}
