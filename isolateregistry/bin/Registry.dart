library isoalteregistry.registry;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'WebSocketServer.dart';

import 'dart:io' show HttpServer, HttpRequest;
import 'dart:convert' show JSON;
import "package:rest/http_rest.dart";

part 'Endpoint.dart';

/**
 *
 * if just network with all other systems goes down ? connection is re-established automatically by client
 * TODO:
 * 1. Create a simple form / web-interface
 * 2. Maintain a list of connected clients
 *    * should be able to identify Bootstrappers from normal isolate system?
 *    * May be isolates will use the socket connection of bootstrapper for queries ?
 *
 */

Registry r;

main() {
  r = new Registry();
  startRestServer();
}

class Registry {
  WebSocketServer wss;
  List<_Bootstrapper> _connectedBootstrappers;

  static String defaultPath = "/registry";
  static int defaultPort = 42044;

  Registry() {
    _connectedBootstrappers = new List();
    wss = new WebSocketServer(defaultPort, defaultPath, _onConnect, _onData, _onDisconnect);

//    new Timer(const Duration(seconds:10),() {
//      _deployIsolate(_connectedBootstrappers.elementAt(3).socket);
//    });
  }

  _onConnect(WebSocket socket, String remoteIP, String remotePort) {
    _connectedBootstrappers.add(new _Bootstrapper(socket, remoteIP, remotePort));
    _displayAllBootstrappers();
  }

  _onData(WebSocket socket, var msg) {

  }

  _onDisconnect(WebSocket socket) {
    _Bootstrapper bootstrapper = _getBootstrapperBySocket(socket);
    if(bootstrapper != null) {
      _connectedBootstrappers.remove(bootstrapper);
    }
    socket.close();
    _displayAllBootstrappers();
  }

  _deployIsolate(WebSocket socket) {
    //Temporary  :
    // as soon as bootstrapper connects, make it start an isolate system
    //TODO: refactor
    Map message = new Map();
    message['action'] = "action.addIsolate"; //SystemBootstrapper.ADD_ISOLATE
    message['messageQueuingSystemServer'] = "ws://localhost:42043/mqs";
    message['systemId'] = "dynamicSystem";
    message['isolateName'] = "helloPrinter";
    message['uri'] = "/Users/sushil/workspace/helloSystem/bin/HelloPrinter.dart";
    message['workerPaths'] = ["localhost", "localhost"];
    message['routerType'] = "random"; //Router.RANDOM
    message['hotDeployment'] = true;
    message['args'] = null;

    socket.add(JSON.encode(message));
  }

  _displayAllBootstrappers() {
    print("List of connected Systems:");
    for(_Bootstrapper _bootstrapper in _connectedBootstrappers) {
      print("${_bootstrapper.ip} : ${_bootstrapper.port}");
    }
  }

  _Bootstrapper _getBootstrapperBySocket(WebSocket socket) {
    for(_Bootstrapper bootstrapper in _connectedBootstrappers) {
      if(bootstrapper.socket == socket) {
        return bootstrapper;
      }
    }
    return null;
  }

  _Bootstrapper _getBootstrapperById(String id) {
    for(_Bootstrapper bootstrapper in _connectedBootstrappers) {
      if(bootstrapper.id == id) {
        return bootstrapper;
      }
    }
    return null;
  }
}

Map getConnectedSystems() {
  Map systems = new Map();
  for(_Bootstrapper bootstrapper in r._connectedBootstrappers) {
    systems[bootstrapper.socket.hashCode.toString()] = "${bootstrapper.ip}:${bootstrapper.port}";
  }

  return systems;
}

class _Bootstrapper {
  String _id;
  String _ip;
  String _port;
  WebSocket _socket;

  _Bootstrapper(this._socket, this._ip, this._port) {
    _id = _socket.hashCode.toString();
  }

  String get id => _id;
  set id(String value) => _id = value;

  WebSocket get socket => _socket;
  set socket(WebSocket value) => _socket = value;

  String get ip => _ip;
  set ip(String value) => _ip = value;

  String get port => _port;
  set port(String value) => _port = value;

}
