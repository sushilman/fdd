library isolatesystem.filemonitor.FileMonitor;

import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:convert';

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

fileMonitor(Map args) {
  new FileMonitor(args);
}

class FileMonitor extends Worker {
  bool killed = false;
  FileMonitor(Map args) : super.internal(args) {
    sendPort.send([SenderType.FILE_MONITOR, id, Action.CREATED, workerReceivePort.sendPort]);

    startMonitoring(Uri.parse(args['workerUri']));
  }

  onReceive(var message) {

  }

  startMonitoring(Uri uri) {
    int seconds = 1;
    var oldHash;
    var hash;
    HttpClient httpClient = new HttpClient();
    _log ("Monitoring started for uri $uri");
    Duration duration = new Duration(milliseconds:100);
    if(uri.toString().startsWith("http://")
    || uri.toString().startsWith("https://")
    || uri.toString().startsWith("ftp://")) {
      new Timer.periodic(duration, (t) {
        if(killed) {
          t.cancel();
        } else {
          httpClient.getUrl(uri)
          .then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) => response.listen((value) {
            List<int> fileContent = new List<int>();
            fileContent.addAll(value);
            hash = _calcHash(fileContent);
            //_log("Hash:" + hash);
            if (oldHash == null) {
              oldHash = hash;
            } else if (hash != null) {
              if (oldHash != hash) {
                oldHash = hash;
                _restartIsolate();
              }
            }
          }));
        }
      });
    } else {
      File file = new File.fromUri(uri);
      new Timer.periodic(duration, (t) {
        if(killed) {
          t.cancel();
          _log("Timer cancelled");
        } else {
          file.readAsBytes().then((bytes) {
            List<int> fileContent = new List<int>();
            fileContent.addAll(bytes);
            hash = _calcHash(fileContent);
            //_log("Hash:" + hash);
            if (oldHash == null) {
              oldHash = hash;
            } else if (hash != null) {
              if (oldHash != hash) {
                oldHash = hash;
                _restartIsolate();
              }
            }
          });
        }
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
    sendPort.send(JSON.encode(MessageUtil.create(SenderType.FILE_MONITOR, id, Action.RESTART, {'to': this.me})));
    _log("Restart command issued !");
  }

  _log(var text) {
    //print(text);
  }

  @override
  kill() {
    this.killed = true;
    _log("KILL fileMonitor $id");
  }
}
