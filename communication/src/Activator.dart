import 'dart:io';
import 'dart:async';
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
 */
class Activator {
  static String defaultPath = "/activator";
  static int defaultPort = 42042;

  Activator() {
    listenOn(defaultPort, defaultPath);
  }

  /*
   * Listen on a websocket address
   */
  void listenOn(int port, String path) {
    WebSocketServer wss = new WebSocketServer(port, path);
  }
}

void main() {
  new Activator();
}