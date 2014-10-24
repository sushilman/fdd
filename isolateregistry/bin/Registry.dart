library isoalteregistry.registry;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'WebSocketServer.dart';
//import 'Endpoint.dart';
import 'MyEndpoint.dart';

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

Registry registry;

main() {
  registry = new Registry();
  MyEndpoint e = new MyEndpoint();
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
//
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

  _deployIsolateDep(WebSocket socket) {
    //Temporary  :
    // as soon as bootstrapper connects, make it start an isolate system
    //TODO: refactor
    Map message = new Map();
    message['action'] = "action.addIsolate"; //SystemBootstrapper.ADD_ISOLATE
    message['messageQueuingSystemServer'] = "ws://192.168.2.2:42043/mqs";
    message['systemId'] = "isolateSystem";
    message['isolateName'] = "helloPrinter";
    message['uri'] = "http://192.168.2.2/helloSystem/HelloPrinter.dart";
    message['workerPaths'] = ["localhost", "localhost"];
    message['routerType'] = "random"; //Router.RANDOM
    message['hotDeployment'] = false;
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

  deployIsolate(Map data) {
    String id = data.remove('bootstrapperId');

    _Bootstrapper bootstrapper = _getBootstrapperById(id);

    print("Before sending: $data");

    if(bootstrapper != null)
      bootstrapper.socket.add(JSON.encode(data));
    else
      print("Bootstrapper is not available");
  }

  List getConnectedSystems() {
    return _connectedBootstrappers;
  }
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

  toJson() {
    return {'bootstrapperId':_id,'ip':_ip,'port':_port};
  }
}
