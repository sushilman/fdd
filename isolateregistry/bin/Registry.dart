library isoalteregistry.registry;

import 'dart:io';
import 'dart:convert';
import 'WebSocketServer.dart';

/**
 *
 * if just network with all other systems goes down ? connection is re-established automatically by client
 */

class Registry {
  WebSocketServer wss;
  static String defaultPath = "/registry";
  static int defaultPort = 42044;

  Registry() {
    wss = new WebSocketServer(defaultPort, defaultPath, _onConnect, _onData, _onDisconnect);
  }

  _onConnect(WebSocket socket) {
    //Temporary  :
    // as soon as bootstrapper connects, make it start an isolate system
    //TODO: refactor
    Map message = new Map();
    message['action'] = "action.addIsolate"; //SystemBootstrapper.ADD_ISOLATE
    message['systemId'] = "dynamicSystem";
    message['isolateName'] = "helloPrinter";
    message['uri'] = "/Users/sushil/workspace/helloSystem/bin/HelloPrinter.dart";
    message['workerPaths'] = ["localhost", "localhost"];
    message['routerType'] = "random"; //Router.RANDOM
    message['hotDeployment'] = true;
    message['args'] = null;

    socket.add(JSON.encode(message));
  }

  _onData(WebSocket socket, var msg) {

  }

  _onDisconnect(WebSocket socket) {
    socket.close();
  }


}

main() {
  new Registry();
}