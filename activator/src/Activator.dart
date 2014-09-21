import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'WebSocketServer.dart';

/*
 * Web socket handler
 *
 * Keeps on listening to any incoming websocket connections
 * Can handle multiple simultaneous connections (don't think it is significant?)
 *
 * Default address is ws://<ip>:42042/activator
 *
 * Spwans isolates that are in the vm where activator is running
 * or spawns an (controller?) isolate for a physical vm
 *
 * How to separate between physical vm and logical system
 * The activator itself can be the central isolate
 *
 *
 * ------------
 * Router of an isolate system will request the activator to spawn isolates
 * So an activator has to:
 *  1. Spawn an isolate
 *  2. Kill/ping an isolate
 *  3. Forward messages to proper isolate
 *
 */
class Activator {
  ReceivePort receivePort;
  SendPort sendPort;
  List<_Isolate> isolates;

  WebSocketServer wss;

  static String defaultPath = "/activator";
  static int defaultPort = 42042;

  Activator() {
    isolates = new List<_Isolate>();
    receivePort = new ReceivePort();
    receivePort.listen((message) {
      _onReceive(message);
    });

    listenOn(defaultPort, defaultPath);
  }

  /**
   * Assumes that evey isolate this Activator is going to spawn
   * will send id along with its send port
   */
  _onReceive(var message) {
    print("Activator: message received from isolate -> $message");
    if(message[1] is SendPort) {
      String id = message[0];
      getIsolateById(id).sendPort = message[1];
      print("Adding sendport to $id");
      wss.send("DONE");
    } else {
      wss.send(JSON.encode(message));
    }
  }
  /*
   * Listen on a websocket address
   */
  void listenOn(int port, String path) {
    wss = new WebSocketServer(port, path, _onData);
  }

  _onData(msg) {
    var message = JSON.decode(msg);
    print("$message");
    print("From onData: ${message[0]}");

    if(message[0] == "SPAWN") {
      String uri = message[1];
      List<String> args = message[2];
      spawnWorker(uri, args);
    } else if (message[0] is String || message[0] is int) {
      forward(message[0], message[1]);
    }
  }

  spawnWorker(String uri, List<String> args) {
    Isolate.spawnUri(Uri.parse(uri), args, receivePort.sendPort).then((isolate) {
      print("Activator: Spawning completed");
      isolates.add(new _Isolate(args[0], isolate));
    });
  }

  forward(String id, var message) {
    getIsolateById(id).sendPort.send(message);
  }

  _Isolate getIsolateById(String id) {
    _Isolate selectedIsolate = null;
    isolates.forEach((isolate) {
      print("Comparing: ${isolate.id} vs ${id} ");
      if(isolate.id == id) {
        selectedIsolate = isolate;
      }
    });

    return selectedIsolate;
  }
}

void main() {
  new Activator();
}

class _Isolate {
  int _id;
  SendPort _sendPort;
  Isolate _isolate;

  _Isolate(this._id, this._isolate);

  set sendPort(SendPort value) => _sendPort = value;
  get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  get isolate => _isolate;

  set id(int value) => _id = value;
  get id => _id;
}
