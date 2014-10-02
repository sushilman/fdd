library isolatesystem.controller.Controller;

import 'dart:isolate';
import 'dart:async';

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
 * TODO: determine from which router the message was sent
 * TODO: also determine to which router the message should be forwarded
 */
main(List<String> args, SendPort sendPort) {
  Controller controller = new Controller(args, sendPort);
}

class Controller {
  String id;
  ReceivePort receivePort;
  SendPort sendPortOfIsolateSystem;
  SendPort self;
  /**
   * Send port the router this controller has spawned
   */
  List<_Router> routers;

  Controller(List<String> args, this.sendPortOfIsolateSystem) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;
    sendPortOfIsolateSystem.send(receivePort.sendPort);
    id = args[0];

    routers = new List<_Router>();

    receivePort.listen((message) {
      _onReceive(message);
    });

    print("Controller: Ready...");
    //_spawnRouter1(receivePort, routerUri, workerUri, workersCount, workersPaths);
  }

  _onReceive1(var message) {
    //print("Controller: $message");
    if(message is List) {
      String id = message[0];
      _Router router = _getRouterById(id);
      if(message[1] is SendPort) {
        router.sendPort = message;
      } else {
        String senderId = message[0];
        switch(message[1]) {
          case Action.SPAWN:
            //Do Nothing
            break;
          case Action.READY:
            for (int i = 0; i < router.workersCount; i++) {
              sendPortOfIsolateSystem.send([id, Action.PULL_MESSAGE]);
            }
            break;
          case Action.PULL_MESSAGE:
            // The result message? along with DONE action
            // to be en-queued in MQS
            if(message.length > 2) {
              // may be some additional information of
              // the isolate and/or the original sender?
              sendPortOfIsolateSystem.send(message);
            }

            sendPortOfIsolateSystem.send([Action.PULL_MESSAGE]);
            break;
          case Action.RESTART_ALL:
            router.sendPort.send(message);
            break;
          default:
            print ("Controller: Unknown Action, delegating to router ${message[0]}");
            router.sendPort.send(message);
            break;
        }
      }
    } else if (message is String) {
      print ("Controller: Unhandled message -> $message");
    }
  }

  _onReceive(message) {
    print("Controller: $message");
    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      String payload = MessageUtil.getPayload(message);

      if(senderType == SenderType.ISOLATE_SYSTEM) {
        _handleMessagesFromIsolateSystem(action, payload);
      } else if (senderType == SenderType.ROUTER) {
        _handleMessagesFromRouters(senderId, action, payload);
      } else {
        print ("Controller: Unknown Sender Type -> $senderType");
      }
    } else {
      print ("Controller: Unknown message: $message");
    }
  }

  _handleMessagesFromIsolateSystem(String action, var payload) {
    switch(action) {
      case Action.SPAWN:
        String routerId = payload[0];
        String workerUri = payload[1];
        List<String> workersPaths = payload[2];
        Uri routerUri = Uri.parse(payload[3]);

        _spawnRouter(routerId, routerUri, workerUri, workersPaths);
        break;
      case Action.RESTART:
        //TODO: means to restart all isolates of a router?
        //issuing a restart command for single isolate does not make sense
        // get id of router, send restart command to that router
        String routerId = payload[0];
        _Router router = _getRouterById(routerId);
        router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, id, Action.RESTART_ALL, null));
        break;
      case Action.RESTART_ALL:
        routers.forEach((router) {
          router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, id, Action.RESTART_ALL, null));
        });
        break;
      case Action.NONE:
        String routerId = payload[0];
        _Router router = _getRouterById(routerId);
        router.sendPort.send(MessageUtil.create(SenderType.CONTROLLER, id, Action.NONE, payload[1]));
        break;
      default:
        print("Controller: Unknown Action from System -> $action");
    }
  }

  _handleMessagesFromRouters(String senderId, String action, var payload) {
    print ("Rotuer: getting router $senderId");
    _Router router = _getRouterById(senderId);
    if(payload is SendPort) {
      print ("Setting sendport");
      router.sendPort = payload;
    } else {
      switch (action) {
      //When all isolates have been spawned
        case Action.READY:
          for (int i = 0; i < router.workersCount; i++) {
            sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, null));
          }
          break;
        case Action.PULL_MESSAGE:
        //TODO: should the response message be sent along with pullmessage or should it be a separate action?
          sendPortOfIsolateSystem.send(MessageUtil.create(SenderType.CONTROLLER, senderId, Action.PULL_MESSAGE, payload));
          break;
        default:
          print("Controller: Unknown Action from Router: $action");
          break;
      }
    }
  }

  _spawnRouter1(ReceivePort receivePort, Uri routerUri, String workerUri, int workersCount, String workersPaths) {
    Isolate.spawnUri(routerUri, [workerUri, workersCount.toString(), workersPaths], receivePort.sendPort).then((isolate) {
      _Router router = new _Router("id", routerUri, workersCount);
      routers.add(router);
    });
  }

  _spawnRouter(String routerId, Uri routerUri, String workerUri, List<String> workersPaths) {
    Isolate.spawnUri(routerUri, [routerId, workerUri, workersPaths], receivePort.sendPort).then((isolate) {
      _Router router = new _Router(routerId, routerUri, workersPaths.length);
      routers.add(router);
    });
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