import 'dart:html' show WebSocket, MessageEvent;
import 'dart:isolate';
import 'dart:convert';
import 'dart:async';

import 'package:isolatesystem/IsolateSystem_browser.dart';
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

  var webSocket;

  static const String ADD_ISOLATE = "action.addIsolate";
  static const String KILL = "action.kill";
  String registryPath;

  //Browser.ParagraphElement output = Browser.querySelector('#output');

  SystemBootstrapper([List<String> args, SendPort this.sendPort]) {
    receivePort = new ReceivePort();
    _me = receivePort.sendPort;
    _systems = new List();
    //sendPort.send(_me);
    receivePort.listen(_onReceive);

    registryPath = "ws://localhost:42044/registry";

    print("Connecting to $registryPath ...");

    _initWebSocket();
  }

  /**
   * May be using exception handling,
   * websocket can be initialized for vm as well as for browser
   * try {vm initialization} catch(e) {browser initialization}
   *
   * TODO: Needs tweaking and testing in Browser
   *
   * isolatesystem is has dependency on dart:io which causes exception while loading script in browser
   *
   */
  void _initWebSocket() {
      WebSocket webSocket = new WebSocket(registryPath);
      webSocket.onOpen.listen((MessageEvent e) {
        print("Connected to Registry");
      });
      webSocket.onMessage.listen(_onData);
      webSocket.onError.listen(_onError);
      webSocket.onClose.listen((_) => _onDone);
  }
/*
  void outputMessage(Browser.Element e, String message){
    print(message);
    e.appendText(message);
    e.appendHtml('<br/>');

    //Make sure we 'autoscroll' the new messages
    e.scrollTop = e.scrollHeight;
  }
*/

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
    print("Received data: $msg");
    if(msg is MessageEvent) {
      var message = JSON.decode(msg.data);
      _me.send(message);
    } else {
      print("Unknown data received => ${msg.data}");
    }
  }

  void _onReceive(var message) {
    print("Bootstrapper: $message");
    String action = message['action'];

    switch(action) {
      case ADD_ISOLATE:
        String systemName = message['isolateSystemName'];
        String pathToMQS = message['messageQueuingSystemServer'];
        String name = message['isolateName'];
        String uri = message['uri'];
        String workersPaths = message['workerPaths'];
        String routerType = message['routerType'];
        bool deploymentType = message['hotDeployment'];
        String extraArgs = message['args'];

        IsolateSystem system = _getSystemByName(systemName);
        if(system == null) {
          system = new IsolateSystem(systemName, pathToMQS);
          _systems.add(system);
        }

        //system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);

        IsolateRef myIsolate = system.addIsolate(name, uri, workersPaths, routerType, hotDeployment:deploymentType, args:extraArgs);
        break;
      case KILL:
        // the isolate system must close all the connections / websocket as well as other isolate ports.
        print("Killing an isolate system is not implemented yet!");
        break;
      default:

    }
  }

  IsolateSystem _getSystemByName(String name) {
    for(IsolateSystem system in _systems) {
      if(system.name == name) {
        return system;
      }
    }
    return null;
  }

//_getSystemById(systemId).addIsolate(name, uri, workersPaths, routerType, hotDeployment: hotDeployment, args:args);
}
