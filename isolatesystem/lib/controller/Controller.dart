library isolatesystem.controller.Controller;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:path/path.dart' show dirname;

import '../message/MessageUtil.dart';
import '../message/SenderType.dart';
import '../action/Action.dart';
import '../IsolateSystem.dart';

/**
 * Controller
 * needs many sendports -> list of all the routers it has spawned
 *
 * Should keep track of free isolates (with the help of router)
 * and send pull request to IsolateSystem
 *
 * TODO: determine from which router the message was sent -> router name (senderId)
 *
 * TODO: also determine to which router the message should be forwarded -> router name (senderId)
 */
main(List<String> args, SendPort sendPort) {
  Controller controller = new Controller(args, sendPort);
}

class Controller {
  String _id;
  ReceivePort _receivePort;
  SendPort _sendPortOfIsolateSystem;
  SendPort _self;

  List<_Router> routers;

  Controller(List<String> args, this._sendPortOfIsolateSystem) {
    _receivePort = new ReceivePort();
    _self = _receivePort.sendPort;
    _sendPortOfIsolateSystem.send(_receivePort.sendPort);
    _id = args[0];

    routers = new List<_Router>();

    _receivePort.listen((message) {
      _onReceive(message);
    });

  }

  _onReceive(message) {
    //print("Controller: $message");
    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      String payload = MessageUtil.getPayload(message);

      switch(senderType) {
        case SenderType.ISOLATE_SYSTEM:
          _handleMessagesFromIsolateSystem(action, payload);
          break;
        case SenderType.ROUTER:
          _handleMessagesFromRouters(senderId, action, payload);
          break;
        case SenderType.FILE_MONITOR:
          _handleMessagesFromFileMonitor(senderId, action, payload);
          break;
        default:
          print ("Controller: Unknown Sender Type -> $senderType");
      }
    } else {
      print ("Controller: Unknown message: $message");
    }
  }

  _handleMessagesFromIsolateSystem(String action, var payload) {
    switch(action) {
      case Action.SPAWN:
        String routerId = payload['name'];
        String workerUri = payload['uri'];
        List<String> workersPaths = payload['workerPaths'];
        Uri routerUri = Uri.parse(payload['routerUri']);
        bool hotDeployment = payload['hotDeployment'];
        var extraArgs = payload['args'];

        _spawnRouter(routerId, routerUri, workerUri, workersPaths, extraArgs);

        if(hotDeployment) {
          _spawnFileMonitor(routerId, workerUri);
        }

        break;
      case Action.RESTART:
        // means to restart all isolates of a router
        // issuing a restart command for single isolate does not make sense
        // get id of router, send restart command to that router
        String routerId = payload[0];
        _Router router = _getRouterById(routerId);
        router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        break;
      case Action.RESTART_ALL:
        routers.forEach((router) {
          router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        });
        break;
      case Action.NONE:
        String routerId = payload[0];
        _Router router = _getRouterById(routerId);
        router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.NONE, payload[1]));
        break;
      default:
        print("Controller: Unknown Action from System -> $action");
    }
  }

  _handleMessagesFromRouters(String senderId, String action, var payload) {
    _Router router = _getRouterById(senderId);
    if(payload is SendPort) {
      router.sendPort = payload;
    } else {
      switch (action) {
      //When all isolates have been spawned
        case Action.READY:
          for (int i = 0; i < router.workersCount; i++) {
            _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          }
          break;
        case Action.PULL_MESSAGE:
        //TODO: should the response message be sent along with pullmessage or should it be a separate action?
          _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, payload));
          break;
        default:
          print("Controller: Unknown Action from Router: $action");
          break;
      }
    }
  }

  _handleMessagesFromFileMonitor(String senderId, String action, var payload) {
    //print("Controller: Message from file monitor $payload");
    switch(action) {
      case Action.RESTART:
        //TODO: means to restart all isolates of a router?
        //issuing a restart command for single isolate does not make sense
        // get id of router, send restart command to that router
        String routerId = payload[0];
        _Router router = _getRouterById(routerId);
        router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        break;
      default:
        break;
    }
  }

  _spawnRouter(String routerId, Uri routerUri, String workerUri, List<String> workersPaths, var extraArgs) {
    Isolate.spawnUri(routerUri, [routerId, workerUri, workersPaths, extraArgs], _receivePort.sendPort).then((isolate) {
      _Router router = new _Router(routerId, routerUri, workersPaths.length);
      routers.add(router);
    });
  }

  _spawnFileMonitor(String routerId, String workerUri) {
    String curDir = dirname(Platform.script.toString());
    Uri fileMonitorUri = Uri.parse(curDir + "/../src/FileMonitor.dart");
    Isolate.spawnUri(fileMonitorUri, ["fileMonitor_$routerId", routerId, workerUri], _receivePort.sendPort);
  }

  _Router _getRouterById(String id) {
    _Router router;
    routers.forEach((_router) {
      if(_router.id == id){
        router = _router;
      }
    });
    return router;
  }
}

class _Router {
  String _id;
  SendPort _sendPort;
  int _workersCount;
  String _type;
  Uri _uri;
  Isolate _isolate;
  Isolate _fileMonitorIsolate;

  String get id => _id;
  set id(String value) => _id = value;

  SendPort get sendPort => _sendPort;
  set sendPort(SendPort value) => _sendPort = value;

  int get workersCount => _workersCount;
  set workersCount(int value) => _workersCount = value;

  String get type => _type;
  set type(String value) => _type = value;

  Uri get uri => _uri;
  set uri(Uri value) => _uri = value;

  Isolate get isolate => _isolate;
  set isolate(Isolate value) => _isolate = value;


  _Router(this._id, this._uri, this._workersCount);
}