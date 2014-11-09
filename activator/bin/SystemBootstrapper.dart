library activator.SystemBootstrapper;

import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';

import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/IsolateRef.dart';

startSystemBootstrapper(List<String> args) {
  main(args);
}

main(List<String> args, [SendPort sendPort]) {
  if(args.length == 1) {
    new SystemBootstrapper(args[0], sendPort);
  } else {
    print("Usage: dart SystemBootstrapper.dart full_websocket_path_of_registry (eg:'ws://localhost:42044/registry')");
  }
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

  var webSocket;

  static const String ADD_ISOLATE = "action.addIsolate";
  static const String KILL = "action.kill";
  static const String LIST_SYSTEMS = "action.listSystems";

  static const String DEFAULT_REGISTRY_PATH = "ws://localhost:42044/registry";

  String registryPath = DEFAULT_REGISTRY_PATH;

  SystemBootstrapper(String registryPath, [SendPort this.sendPort]) {
    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    _systems = new List();
    receivePort.listen(_onReceive);

    if(registryPath.isNotEmpty) {
      this.registryPath = registryPath;
    }

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
        IsolateRef myIsolate = system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);
        break;
      case LIST_SYSTEMS:
        Map <String, List> fullDetails = new Map<String, List>();
        for(IsolateSystem system in _systems) {
          system.getRunningIsolates().then((String value) {
            if(value != null) {
              List<Map> list1 = JSON.decode(value);
              fullDetails[system.name] = list1;
              _log('Response: $list1');
              if(fullDetails.length == _systems.length) {
                webSocket.add(JSON.encode({
                  'requestId':message['requestId'], 'details':fullDetails
                }));
              }
            }
          });
        }

        break;
      case KILL:
        String systemName = message['isolateSystemName'];
        if (message.containsKey('isolateName')) {
          IsolateSystem s = _getSystemByName(systemName);
          String isolateName = message['isolateName'];
          if(s != null) {
            s.killIsolate(isolateName);
          }
        } else {
          IsolateSystem s = _getSystemByName(systemName);
          if(s != null) {
            s.killSystem();
            _systems.remove(s);
          }
        }
      break;
    }
  }

  void _log(var text) {
    //print(text);
  }

  IsolateSystem _getSystemByName(String systemName) {
    return _systems.firstWhere((system) => (system.name == systemName), orElse:() => null);
  }

}
