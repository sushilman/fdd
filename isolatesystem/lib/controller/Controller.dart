library isolatesystem.controller.Controller;

import 'dart:convert';
import 'dart:isolate';

import '../message/MessageUtil.dart';
import '../message/SenderType.dart';
import '../message/ExceptionMessage.dart';

import '../action/Action.dart';

import '../router/Router.dart';
import '../router/Random.dart';
import '../router/RoundRobin.dart';
import '../router/Broadcast.dart';

import '../filemonitor/FileMonitor.dart';

/**
 * Controller
 * needs many sendports -> list of all the routers it has spawned
 *
 * Should keep track of free isolates (with the help of router)
 * and send pull request to IsolateSystem
 *
 */

controller(Map args) {
  Controller controller = new Controller(args);
}

class Controller {
  static const GET_RUNNING_ISOLATES = "action.getRunningIsolates";
  String _id;
  ReceivePort _receivePort;
  SendPort _sendPortOfIsolateSystem;
  SendPort _me;

  List<_Router> _routers;

  List _messageBuffer;

  //Stopwatch stopwatch;

  Controller(Map args) {
    _id = args['id'];
    _sendPortOfIsolateSystem = args['sendPort'];
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _sendPortOfIsolateSystem.send(_receivePort.sendPort);

    _routers = new List<_Router>();

    _messageBuffer = new List();
    //stopwatch = new Stopwatch();

    _receivePort.listen((message) {
        _onReceive(message);


    });
  }

  _onReceive(message) {
      _log("Controller: $message");
      if (MessageUtil.isValidMessage(message)) {
        if(message is String) {
          message = JSON.decode(message);
        }
        String senderType = MessageUtil.getSenderType(message);
        String senderId = MessageUtil.getId(message);
        String action = MessageUtil.getAction(message);
        var payload = MessageUtil.getPayload(message);

        switch (senderType) {
          case SenderType.ISOLATE_SYSTEM:
            _handleMessagesFromIsolateSystem(action, payload, message);
            break;
          case SenderType.ROUTER:
            _handleMessagesFromRouters(senderId, action, payload);
            break;
          case SenderType.FILE_MONITOR:
            _handleMessagesFromFileMonitor(senderId, action, payload, message);
            break;
          default:
            _log("Controller: Unknown Sender Type -> $senderType");
        }
      } else {
        _log("Controller: Unknown message: $message");
      }
    //});
  }

  _handleMessagesFromIsolateSystem(String action, var payload, var fullMessage) {
    switch(action) {
      case GET_RUNNING_ISOLATES:
        if(payload is SendPort) {
          payload.send(JSON.encode(_routers));
        }
        break;
      case Action.SPAWN:
        String routerId = payload['name'];
        String workerUri = payload['uri'];
        List<String> workersPaths = payload['workerPaths'];
        String routerType = payload['routerType'];
        bool hotDeployment = payload['hotDeployment'];
        var extraArgs = payload['args'];

        _spawnRouter(routerId, routerType, workerUri, workersPaths, extraArgs);

        if(hotDeployment) {
          _spawnFileMonitor(routerId, workerUri);
        }

        break;
      case Action.RESTART:
        String routerId = payload['to'];
        _Router router = _getRouterById(routerId);
        _sendToRouter(router, MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        break;
      case Action.RESTART_ALL:
        for(_Router router in _routers) {
          _sendToRouter(router, MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        }
        break;
      case Action.NONE:
        String routerId = payload['to'];
        if(routerId != null) {
          _Router router = _getRouterById(routerId);
          if(router == null || router.sendPort == null) {
            _messageBuffer.add(fullMessage);
          } else {
            _sendToRouter(router, MessageUtil.create(SenderType.CONTROLLER, _id, Action.NONE, payload));
          }
        } else {
          _log("Controller: Destination Isolate unknown !");
        }
        break;
      case Action.KILL:
        _Router router = _getRouterById(payload['routerId']);
        print("Controller: killing router with ${router.id}");
        if(router == null || router.sendPort == null) {
          _messageBuffer.add(fullMessage);
        } else {
          fullMessage = MessageUtil.setSenderType(SenderType.CONTROLLER, fullMessage);
          _sendToRouter(router, fullMessage);
          if(router.hotDeployment) {
            router.fileMonitorSendPort.send(JSON.encode(fullMessage));
          }
          _routers.remove(router);
          print("Controller: killing msg sent");
        }
        break;

      case Action.KILL_ALL:
        for(_Router router in _routers) {
          fullMessage = MessageUtil.setSenderType(SenderType.CONTROLLER, fullMessage);
          _sendToRouter(router, fullMessage);
        }
        _receivePort.close();
        break;
      default:
        _log("Controller: Unknown Action from System -> $action");
    }
  }

  _handleMessagesFromRouters(String senderId, String action, var payload) {
    _log("Sender Router: $senderId");
    if(payload is SendPort) {
      _Router router = _getRouterById(senderId);
      router.sendPort = payload;
      _flushBuffer();
      _sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
    } else {
      switch (action) {
        case Action.SEND:
        case Action.REPLY:
          _sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.SEND, payload));
          //_sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          //print("\nController Sent At: ${new DateTime.now().millisecondsSinceEpoch} & elapsed microseconds ${stopwatch.elapsedMicroseconds}: $payload");
          break;
        case Action.ASK:
          _sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.ASK, payload));
          _sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          break;
        case Action.CREATED:
          _sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          break;
        case Action.PULL_MESSAGE:
          Stopwatch s = new Stopwatch();
          s.start();
          s.reset();
          _sendToIsolateSystem(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          _log("Time taken to send pull request => ${s.elapsedMicroseconds}");
          break;
        case Action.ERROR:
          print("Received error so removing router from list");
          if(payload['exception'] == ExceptionMessage.ISOLATE_SPAWN_EXCEPTION) {
            _routers.removeWhere((router) {
              _sendToRouter(router, MessageUtil.create(SenderType.CONTROLLER, senderId, Action.KILL, null));
              return (router.id == senderId);
            });
          }
          break;
        default:
          _log("Controller: Unknown Action from Router: $action");
          break;
      }
    }
  }

  _handleMessagesFromFileMonitor(String senderId, String action, var payload, var fullMessage) {
    //_out("Controller: Message from file monitor $payload");
    if(payload is SendPort) {
      String routerId = senderId.split('_').last;
      _Router router = _getRouterById(routerId);
      if(router != null) {
        router.fileMonitorSendPort = payload;
        router.hotDeployment = true;
      } else {
        _messageBuffer.add(fullMessage);
      }
    } else {
      switch(action) {
        case Action.RESTART:
          String routerId = payload['to'];
          _Router router = _getRouterById(routerId);
          if(router != null && router.sendPort != null) {
            _sendToRouter(router, MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
          }
          break;
        default:
          break;
      }
    }
  }

  _sendToIsolateSystem(var message) {
    _sendPortOfIsolateSystem.send(JSON.encode(message));
  }

  _sendToRouter(_Router router, var message) {
    if(router.sendPort != null) {
      router.sendPort.send(JSON.encode(message));
    }
  }

  _sendToSelf(var message) {
    _me.send(JSON.encode(message));
  }

  _spawnRouter(String routerId, String routerType, String workerUri, List<String> workersPaths, var extraArgs) {

    var router;
    switch(routerType) {
      case Router.RANDOM:
        router = random;
        break;
      case Router.ROUND_ROBIN:
        router = roundRobin;
        break;
      case Router.BROADCAST:
        router = broadcast;
        break;
      case Router.CUSTOM:
        //TODO: spawn by uri?
      default:
    }

    Isolate.spawn(router, {'id':routerId, 'workerUri':workerUri, 'workerPaths':workersPaths, 'extraArgs':extraArgs, 'sendPort': _me}).then((isolate){
      _Router router = new _Router(routerId, routerType, workerUri, workersPaths);
      _routers.add(router);
    });
  }

  _spawnFileMonitor(String routerId, String workerUri) {
    Isolate.spawn(fileMonitor, {'id':'fileMonitor_$routerId', 'routerId':routerId, 'workerUri':workerUri, 'sendPort': _me});
  }

  _Router _getRouterById(String id) {
    _routers.where((router) {return (router.id == id || router.id == id.substring(0, id.lastIndexOf('/')));});
//    for(_Router router in _routers) {
//      if(router.id == id || router.id == id.substring(0, id.lastIndexOf('/'))) {
//        return router;
//      }
//    }
//    return null;
  }

  void _flushBuffer() {
    int len = _messageBuffer.length;
    for(int i = 0; i < len; i++) {
      _sendToSelf(_messageBuffer.removeAt(0));
    }
  }

  _log(String text) {
    //print(text);
  }
}

class _Router {
  String _id;
  SendPort _sendPort;
  String _workerUri;
  List<String> _workersPaths;
  int _workersCount;
  String _type;
  Isolate _isolate;
  SendPort _fileMonitorSendPort;
  bool _hotDeployment;

  String get id => _id;
  set id(String value) => _id = value;

  SendPort get sendPort => _sendPort;
  set sendPort(SendPort value) => _sendPort = value;

  int get workersCount => _workersCount;
  set workersCount(int value) => _workersCount = value;

  String get type => _type;
  set type(String value) => _type = value;

  Isolate get isolate => _isolate;
  set isolate(Isolate value) => _isolate = value;

  SendPort get fileMonitorSendPort => _fileMonitorSendPort;
  set fileMonitorSendPort(SendPort value) => _fileMonitorSendPort = value;

  bool get hotDeployment => _hotDeployment;
  set hotDeployment(bool value) => _hotDeployment = value;

  _Router(this._id, this._type, this._workerUri, this._workersPaths) {
    this._workersCount = this._workersPaths.length;
    this._hotDeployment = false;
  }

  Map toJson() {
    Map m = {};
    m['id'] = _id;
    m['workerUri'] = _workerUri;
    m['workersCount'] = _workersCount;
    m['workersPaths'] = _workersPaths;
    m['routerType'] = _type;
    m['hotDeployment'] = _hotDeployment;
    return m;
  }
}