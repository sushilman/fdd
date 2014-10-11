import 'dart:io';
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';

import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/IsolateRef.dart';

main(List<String> args, SendPort sendPort) {
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

  WebSocket ws;

  static const String ADD_ISOLATE = "action.addIsolate";
  static const String KILL = "action.kill";
  String registryPath;

  SystemBootstrapper(List<String> args, SendPort this.sendPort) {
    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    _systems = new List();
    //sendPort.send(_me);
    receivePort.listen(_onReceive);

    registryPath = args[0];
    print("Connecting to $registryPath ...");

    _initWebSocket();
  }

  void _initWebSocket() {
    WebSocket.connect(registryPath).then(_handleWebSocket).catchError(_onError);
  }

  void _handleWebSocket(WebSocket socket) {
    ws = socket;
    if(ws != null && ws.readyState == WebSocket.OPEN) {
      print("Connected to registry!");
    }
    ws.listen(_onData, onDone:_onDone);
  }

  void _onError(var message) {
    print("Could not connect, retrying...");
    new Timer(new Duration(seconds:3), () {
      print ("Retrying...");
      _initWebSocket();
    });
  }

  void _onDone() {
    print("Connection closed by server!");
    print("Reconnecting...");
    _initWebSocket();
  }

  void _onData(var msg) {
    var message = JSON.decode(msg);
    _me.send(message);
  }

  void _onReceive(var message) {
    print("Bootstrapper: $message");
    String action = message['action'];

    switch(action) {
      case ADD_ISOLATE:
        String systemId = message['systemId'];
        String name = message['isolateName'];
        String uri = message['uri'];
        String workersPaths = message['workerPaths'];
        String routerType = message['routerType'];
        bool deploymentType = message['hotDeployment'];
        String extraArgs = message['args'];

        IsolateSystem system = _getSystemById(systemId);
        if(system == null) {
          system = new IsolateSystem(systemId);
          _systems.add(system);
        }

        //system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);

        IsolateRef helloPrinter = system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);
        helloPrinter.send("\n\n\n Print It\n\n\n", replyTo:helloPrinter);
        break;
      case KILL:
        // the isolate system must close all the connections / websocket as well as other isolate ports.
        print("Killing an isolate system is not implemented yet!");
        break;
      default:

    }
  }

  IsolateSystem _getSystemById(String id) {
    for(IsolateSystem system in _systems) {
      if(system.id == id) {
        return system;
      }
    }
    return null;
  }
//_getSystemById(systemId).addIsolate(name, uri, workersPaths, routerType, hotDeployment: hotDeployment, args:args);
}
