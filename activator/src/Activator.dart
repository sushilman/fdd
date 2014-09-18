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
  List<_Worker> workers;

  static String defaultPath = "/activator";
  static int defaultPort = 42042;

  Activator() {
    workers = new List<_Worker>();
    receivePort = new ReceivePort();
    receivePort.listen((message) {
      _onReceive;
    });
    listenOn(defaultPort, defaultPath);
  }

  _onReceive(message) {
    if(message[1] is SendPort) {
      sendPort = message[1];
    }
  }
  /*
   * Listen on a websocket address
   */
  void listenOn(int port, String path) {
    WebSocketServer wss = new WebSocketServer(port, path, _onData);
  }

  _onData(msg) {
    JsonCodec message = JSON.decode(msg);
    print("$message");
    print("From onData: ${message[0]}");

    if(message[0] == "SPAWN") {
      String uri = message[1];
      List<String> args = message[2];
      spawnWorker(uri, args);
    }
  }

  spawnWorker(String uri, List<String> args) {
    print("Inside spawnWorker");
    Isolate.spawnUri(Uri.parse(uri), args, receivePort.sendPort).then((isolate) {
      print("Activator: Spawning completed");
    });
  }

  forwardMessage() {

  }

}

void main() {
  new Activator();
}

class _Worker {
  int _id;
  SendPort _sendPort;
  Isolate _isolate;

  _Worker(this._id, this._isolate);

  set sendPort(SendPort value) => _sendPort = value;
  get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  get isolate => _isolate;

  set id(int value) => _id = value;
  get id => _id;
}
