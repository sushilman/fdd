library isolatesystem.controller.Controller;

import 'dart:io';
import 'dart:isolate';
import 'dart:async';

import 'package:path/path.dart' show dirname;

import '../message/MessageUtil.dart';
import '../message/SenderType.dart';
import '../action/Action.dart';
import '../IsolateSystem.dart';
import '../worker/Worker.dart';

/**
 * Controller
 * needs many sendports -> list of all the routers it has spawned
 *
 * Should keep track of free isolates (with the help of router)
 * and send pull request to IsolateSystem
 *
 */
main(List<String> args, SendPort sendPort) {
  Controller controller = new Controller(args, sendPort);
}

class Controller {
  String _id;
  ReceivePort _receivePort;
  SendPort _sendPortOfIsolateSystem;
  SendPort _me;

  List<_Router> _routers;

  Controller(List<String> args, this._sendPortOfIsolateSystem) {
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _sendPortOfIsolateSystem.send(_receivePort.sendPort);
    _id = args[0];

    _routers = new List<_Router>();

    _receivePort.listen((message) {
      try {
        _onReceive(message);
      } catch (e, stackTrace) {
        print ("Exception : $e, StackTrace: $stackTrace");
        try {
          _sendPortOfIsolateSystem.send(e);
        } catch (e2, s2) {
          _sendPortOfIsolateSystem.send(new Exception("UnknownException"));
        }
      }
    });
  }

  _onReceive(message) {
    //return new Future(() {
      _out("Controller: $message");
      if (MessageUtil.isValidMessage(message)) {
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
            _handleMessagesFromFileMonitor(senderId, action, payload);
            break;
          default:
            _out("Controller: Unknown Sender Type -> $senderType");
        }
      } else {
        _out("Controller: Unknown message: $message");
      }
    //});
  }

  _handleMessagesFromIsolateSystem(String action, var payload, var fullMessage) {
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
        String routerId = payload['to'];
        _Router router = _getRouterById(routerId);
        router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        break;
      case Action.RESTART_ALL:
        for(_Router router in _routers) {
          router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.RESTART_ALL, null));
        }
        break;
      case Action.NONE:
      //Controller: {senderType: senderType.isolate_system, id: isolateSystem, action: action.none, payload: {to: helloPrinter, message: {"message":"Enqueue this message 40"}}}
        String routerId = payload['to'];
        if(routerId != null) {
          _Router router = _getRouterById(routerId);
          if(router == null || router.sendPort == null) {
            _me.send(fullMessage);
          } else {
            router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, _id, Action.NONE, payload));
          }
        } else {
          _out("Controller: Destination Isolate unknown !");
        }
        break;
      case Action.KILL:
        for(_Router router in _routers) {
          fullMessage = MessageUtil.setSenderType(SenderType.CONTROLLER, fullMessage);
          router.sendPort.send(fullMessage);
        }
        _receivePort.close();
        break;
      default:
        _out("Controller: Unknown Action from System -> $action");
    }
  }

  _handleMessagesFromRouters(String senderId, String action, var payload) {
    _Router router = _getRouterById(senderId);
    if(payload is SendPort) {
      router.sendPort = payload;
      _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
    } else {
      switch (action) {
      //When all isolates have been spawned
        case Action.REPLY:
        /**
         * TODO: Discuss
         * Re-route without sending it to top level queue?
         * But this causes issues -> if one isolate keeps sending a lots of messages and another one is slow to react?
         *
         * That's why we have MQS with rabbit-mq in backend
         * which only serves message on demand from isolate(pool)
         *
         * But, that's why we have load balancing - router with pool of isolates to take care of such loads
         * if an isolate is known/expected to be slow, the developer should spawn more number of such isolates.
         */

//          _Router targetRouter = _getRouterById(_getIdOfTargetIsolatePool(payload));
//          if(targetRouter != null) {
//            targetRouter.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.NONE, payload));
//          } else {
//            _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.REPLY, payload));
//          }
          _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.REPLY, payload));
          _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          break;
        case Action.CREATED:
          _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          break;
        case Action.PULL_MESSAGE:
        //TODO: should the response message be sent along with pullmessage or should it be a separate action?
          _sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          break;
        default:
          _out("Controller: Unknown Action from Router: $action");
          break;
      }
    }
  }

  _handleMessagesFromFileMonitor(String senderId, String action, var payload) {
    //_out("Controller: Message from file monitor $payload");
    switch(action) {
      case Action.RESTART:
        // should all isolates of a router be restarted?
        // issuing a restart command for single isolate does not make sense
        // get id of router, send restart command to that router
        String routerId = payload['to'];
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
      _routers.add(router);
    });
  }

  _spawnFileMonitor(String routerId, String workerUri) {
    String curDir = dirname(Platform.script.toString());
    Uri fileMonitorUri = Uri.parse(curDir + "/../src/FileMonitor.dart");
    Isolate.spawnUri(fileMonitorUri, ["fileMonitor_$routerId", routerId, workerUri], _receivePort.sendPort);
  }

  _Router _getRouterById(String id) {
    for(_Router router in _routers) {
      if(router.id == id){
        return router;
      }
    }
    return null;
  }

  String _getIdOfTargetIsolatePool(Map payload) {
    if(payload is Map && payload.containsKey(Worker.TO)) {
      return payload[Worker.TO];
    }
    return null;
  }

  _out(String text) {
    print(text);
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