library activator.SystemBootstrapper;

import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';

import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/IsolateRef.dart';

main([List<String> args, SendPort sendPort]) {
  new SystemBootstrapper(args, sendPort);
}

/**
 * Isolate that connects to Registry and
 * bootstraps an isolate system if does not exists
 * else, simply adds an isolate
 * The deployed system connects to MQS and receives messages from there
 */
class SystemBootstrapper {
  ReceivePort receivePort;
  SendPort sendPort;
  SendPort _me;
  List<IsolateSystem> _systems;

  // Map of System -> list of isolates it is running
  Map<String, List<_Worker>> _runningIsolates;

  var webSocket;

  static const String ADD_ISOLATE = "action.addIsolate";
  static const String KILL = "action.kill";
  static const String LIST_SYSTEMS = "action.listSystems";
  String registryPath;

  SystemBootstrapper([List<String> args, SendPort this.sendPort]) {
    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    _systems = new List();
    _runningIsolates = new Map();
    //sendPort.send(_me);
    receivePort.listen(_onReceive);

    registryPath = "ws://localhost:42044/registry";

    _log("Connecting to $registryPath ...");

    _initWebSocket();
  }

  void _initWebSocket() {
    WebSocket.connect(registryPath).then(_handleWebSocket).catchError(_onError);
  }

  void _handleWebSocket(WebSocket socket) {
    webSocket = socket;
    if(webSocket != null && webSocket.readyState == WebSocket.OPEN) {
      _log("Connected to registry!");
    }
    webSocket.listen(_onData, onDone:_onDone);
  }

  void _onError(var message) {
    _log("Could not connect, retrying...");
    new Timer(new Duration(seconds:3), () {
      print ("Retrying...");
      _initWebSocket();
    });
  }

  void _onDone() {
    _log("Connection closed by server!");
    _log("Reconnecting...");
    _initWebSocket();
  }

  void _onData(var msg) {
    var message = JSON.decode(msg);
    _me.send(message);
  }

  void _onReceive(var message) {
    _log("Bootstrapper: $message");
    String action = message['action'];

    switch (action) {
      case ADD_ISOLATE:
        String systemName = message['isolateSystemName'];
        String pathToMQS = message['messageQueuingSystemServer'];
        String name = message['isolateName'];
        String uri = message['uri'];
        String workersPaths = message['workersPaths'];
        String routerType = message['routerType'];
        bool deploymentType = message['hotDeployment'];
        String extraArgs = message['args'];

        IsolateSystem system = _getSystemByName(systemName);
        if (system == null) {
          system = new IsolateSystem(systemName, pathToMQS);
          _systems.add(system);
        }

        //system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);

        IsolateRef myIsolate = system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);

        if (_runningIsolates.containsKey(systemName)) {
          _runningIsolates[systemName].add(new _Worker(name, uri, workersPaths, routerType, deploymentType));
        } else {
          _runningIsolates[systemName] = new List();
          _runningIsolates[systemName].add(new _Worker(name, uri, workersPaths, routerType, deploymentType));
        }
        break;
      case LIST_SYSTEMS:
//        _log("Running Isolates: $_runningIsolates");
//        webSocket.add(JSON.encode({
//            'requestId':message['requestId'], 'details':_runningIsolates
//        }));


        Map <String, List> fullDetails = new Map<String, List>();
        for(String s in _runningIsolates.keys) {
          _getSystemByName(s).getRunningIsolates().then((String value) {
            if(value != null) {
              List<Map> list1 = JSON.decode(value);
              fullDetails[s] = list1;
              _log('Response: $list1');
              if(fullDetails.length == _systems.length) {
                webSocket.add(JSON.encode({
                  'requestId':message['requestId'], 'details':fullDetails
                }));
              }
            }
          });
          //when all details of all systems are fetched
//            webSocket.add(JSON.encode({
//                'requestId':message['requestId'], 'details':fullDetails
//            }));
        }

        break;
      case KILL:
      // the isolate system must close all the connections / websocket as well as other isolate ports.
        String systemName = message['isolateSystemName'];
        if (message.containsKey('isolateName')) {
          IsolateSystem s = _getSystemByName(systemName);
          String isolateName = message['isolateName'];
          if(s != null) {
            s.killIsolate(isolateName);
            _removeWorkerFromSystem(systemName, isolateName);
          }
        } else {
          IsolateSystem s = _getSystemByName(systemName);
          if(s != null) {
            s.killSystem();
            _removeSystemByName(systemName);
          }
        }
      break;
    }
  }

  void _log(var text) {
    //print(text);
  }

  IsolateSystem _getSystemByName(String name) {
    for(IsolateSystem system in _systems) {
      if(system.name == name) {
        return system;
      }
    }
    return null;
  }

  _removeWorkerFromSystem(String isolateSystemName, String workerName) {
    if(_runningIsolates.containsKey(isolateSystemName)) {
      _runningIsolates[isolateSystemName].removeWhere((_Worker w) {
        return w.name == workerName;
      });
    }
  }

  void _removeSystemByName(String name) {
    for(int i = 0; i < _systems.length; i++) {
      if(_systems[i].name == name) {
        _runningIsolates.remove(_systems[i].name);
        _systems.remove(_systems[i]);
        break;
      }
    }
  }

//_getSystemById(systemId).addIsolate(name, uri, workersPaths, routerType, hotDeployment: hotDeployment, args:args);
}


class _Worker {
  String _name;
  String _uri;
  String _paths;
  String _routerType;
  bool _hotDeployment;

  _Worker(this._name, this._uri, this._paths, this._routerType, this._hotDeployment);

  bool get hotDeployment => _hotDeployment;
  set hotDeployment(bool value) => _hotDeployment = value;

  String get routerType => _routerType;
  set routerType(String value) => _routerType = value;

  String get paths => _paths;
  set paths(String value) => _paths = value;

  String get uri => _uri;
  set uri(String value) => _uri = value;

  String get name => _name;
  set name(String value) => _name = value;

  Map toJson() {
    Map json = new Map();
    json['name'] = _name;
    json['uri'] = _uri;
    json['paths'] = _paths;
    json['routerType'] = _routerType;
    json['hotDeployment'] = _hotDeployment;
    return json;
  }
}
