library isoalteregistry.registry;

import 'dart:io';
import 'dart:convert';
import 'WebSocketServer.dart';
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
  List<Bootstrapper> _connectedBootstrappers;
  Map<String, List<HttpRequest>> requestQueue;

  static String defaultPath = "/registry";
  static int defaultPort = 42044;

  Registry() {
    _connectedBootstrappers = new List();
    requestQueue = new Map();
    wss = new WebSocketServer(defaultPort, defaultPath, _onConnect, _onData, _onDisconnect);
  }

  _onConnect(WebSocket socket, String remoteIP, String remotePort) {
    _connectedBootstrappers.add(new Bootstrapper(socket, remoteIP, remotePort));
    _displayAllBootstrappers();
  }

  _onData(WebSocket socket, var msg) {
    // for now only data that arrives from bootstrapper is -> list of systems it is running
    msg = JSON.decode(msg);
    print("List of Isolates Bootstrapper at ${_getBootstrapperBySocket(socket).ip} : ${_getBootstrapperBySocket(socket).port} are:");
    print("$msg");

    HttpRequest req = requestQueue[msg['requestId']].removeAt(0);

    if(requestQueue[msg['requestId']].length == 0) {
      requestQueue.remove(msg['requestId']);
    }

    req.response.write(JSON.encode(msg['details']));
    req.response.close();

  }

  _onDisconnect(WebSocket socket) {
    Bootstrapper bootstrapper = _getBootstrapperBySocket(socket);
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

  getListOfRunningSystems(Bootstrapper node) {
    Map message = new Map();
    message['action'] = "action.listSystems";
    node.socket.add(JSON.encode(message));
  }

  getNodeDetails(String id, HttpRequest request) {
    Bootstrapper node = _getBootstrapperById(id);
    if(node != null && node.socket != null) {
      node.socket.add(JSON.encode({'requestId':request.session.id, 'action':"action.listSystems"}));
      if(requestQueue.containsKey(request.session.id)) {
        requestQueue[request.session.id].add(request);
      } else {
        requestQueue[request.session.id] = new List()..add(request);
      }
    } else {
      request.response.close();
    }
  }

  _displayAllBootstrappers() {
    print("List of connected Systems:");
    for(Bootstrapper _bootstrapper in _connectedBootstrappers) {
      print("${_bootstrapper.ip} : ${_bootstrapper.port}");
    }
  }

  Bootstrapper _getBootstrapperBySocket(WebSocket socket) {
    for(Bootstrapper bootstrapper in _connectedBootstrappers) {
      if(bootstrapper.socket == socket) {
        return bootstrapper;
      }
    }
    return null;
  }

  Bootstrapper _getBootstrapperById(String id) {
    for(Bootstrapper bootstrapper in _connectedBootstrappers) {
      if(bootstrapper.id == id) {
        return bootstrapper;
      }
    }
    return null;
  }

  deployIsolate(Map data) {
    String id = data.remove('bootstrapperId');

    Bootstrapper bootstrapper = _getBootstrapperById(id);
    data['action'] = "action.addIsolate";

    print("Before sending: $data");

    if(bootstrapper != null)
      bootstrapper.socket.add(JSON.encode(data));
    else
      print("Bootstrapper is not available");
  }

  List getConnectedNodes() {
    return _connectedBootstrappers;
  }


  shutdownIsolateSystemOnNode(Map data) {
    String id = data.remove('bootstrapperId');
    Bootstrapper bootstrapper = _getBootstrapperById(id);
    data['action'] = "action.kill";
    print("KILL isolate : $data");
    if(bootstrapper != null) {
      bootstrapper.socket.add(JSON.encode(data));
    } else {
      print("Bootstrapper is not available anymore");
    }
  }

}

class Bootstrapper {
  String _id;
  String _ip;
  String _port;
  WebSocket _socket;

  Bootstrapper(this._socket, this._ip, this._port) {
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
