library isolatesystem.IsolateSystem;

import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' show dirname;

import 'action/Action.dart';
import 'router/Router.dart';
import 'router/Random.dart';
import 'message/MessageUtil.dart';
import 'message/SenderType.dart';


/**
 * Message Structure:
 * [0] -> Message From <Type> - type: isolate system, controller, router, worker
 * [1] -> ID
 * [2] -> Action
 * [3] -> message -> can be String or List
 */

/**
 * This can probably be merged with controller?
 * Or is it better to separate?
 */

/**
 * Controller sends a pull request
 * after which, a message is fetched using messageQueuingSystem
 * from appropriate queue and sent to the controller
 */
class IsolateSystem {
  ReceivePort _receivePort;
  SendPort _sendPortOfController;
  SendPort _self;
  String _id;
  bool _isSystemReady = false;

  Isolate _controllerIsolate;
  Isolate _fileMonitorIsolate;
  bool _hotDeployment = false;

  List<List<String>> _startupBufferedCreationMessages;

  String _workerUri;

  int counter = 0;

  /// @name - Name of this isolate system
  IsolateSystem(String name) {
    _receivePort = new ReceivePort();
    _self = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _id = name;

    _startupBufferedCreationMessages = new List<List<String>>();
    _startController();
  }

  //TODO: make custom routers possible by considering uri instead of routerType
  void addIsolate(String name, String uri, workersPaths, String routerType, {hotDeployment: true}) {
    String routerUri = routerType;

    if(routerType == Router.RANDOM) {
      routerUri = "../router/Random.dart";
    }

    if(_sendPortOfController == null) {
      print("Waiting for controller to be ready");
      _startupBufferedCreationMessages.add([name, uri, workersPaths, routerUri, hotDeployment]);
    } else {
      _self.send(MessageUtil.create(SenderType.SELF, _id, Action.ADD, [name, uri, workersPaths, routerUri, hotDeployment]));
    }
  }

  _onReceive1(message) {
    //print("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
    } else if (message is List) {
      switch(message[0]) {
        case Action.PULL_MESSAGE:
          _pullMessage("abc");
          break;
        case Action.DONE:
          if(message.length > 1) {
            _prepareResponse(message);
          }
          break;
        case Action.RESTART_ALL:
          _sendPortOfController.send(message);
          break;
        default:
          print("IsolateSystem: Unknown Action: ${message[0]}");
          break;
      }
    } else if (message is String) {
      _sendPortOfController.send(message);
    } else {
      print ("IsolateSystem: Unknown message: $message");
    }
  }

  _onReceive(message) {
    print("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
      if(!_startupBufferedCreationMessages.isEmpty) {
        _startupBufferedCreationMessages.forEach((message) {
          _self.send(MessageUtil.create(SenderType.SELF, _id, Action.ADD, message));
        });
        _startupBufferedCreationMessages.clear();
      }
    } else if (MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      String payload = MessageUtil.getPayload(message);

      if (senderType == SenderType.CONTROLLER) {
        _handleMessagesFromController(senderId, action, payload);
      } else {
        _handleOtherMessages(action, payload, senderType);
      }
    } else {
      print ("IsolateSystem: Unknown message: $message");
    }
  }

  _handleMessagesFromController(String senderId, String action, var payload) {
    switch (action) {
      case Action.PULL_MESSAGE:
        _pullMessage(senderId);
        break;
      case Action.DONE:
        if(payload != null) {
          _prepareResponse(payload);
        }
        break;
      case Action.RESTART_ALL:
        _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.RESTART_ALL, payload));
        break;
      default:
        print("IsolateSystem: Unknown Action: $action");
    }
  }

  _handleOtherMessages(action, payload, senderType) {
    switch(action) {
      case Action.ADD:
        print ("IsolateSystem: ADD action with $payload");
        _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.SPAWN, payload));
        break;
      case Action.NONE:
        _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.NONE, payload));
        break;
      default:
        print("IsolateSystem: Unknown Sender: $senderType");
    }
  }

  _startController() {
    String curDir = dirname(Platform.script.toString());
    String controllerUri = curDir + "/packages/isolatesystem/controller/Controller.dart";
    Isolate.spawnUri(Uri.parse(controllerUri), ["controller"], _receivePort.sendPort)
    .then((controller) {
      _controllerIsolate = controller;
    });
  }

  _spawnFileMonitor() {
    String curDir = dirname(Platform.script.toString());
    Uri fileMonitorUri = Uri.parse(curDir + "/packages/isolatesystem/src/FileMonitor.dart");
    Isolate.spawnUri(fileMonitorUri, ["fileMonitor", _workerUri],_receivePort.sendPort).then((monitor) {
      _fileMonitorIsolate = monitor;
    });
  }

  /**
   * Pulls message from MessageQueuingSystem over websocket connection
   */
  _pullMessage(String senderId) {
    // TODO: pull message from appropriate queue from MessageQueuingSystem
    // something like messageQueuingSystem.send(message)
    // then send to sendPort of controller
    // sendPort.send(newMessage);
    //
    _self.send(MessageUtil.create(SenderType.SELF, _id, Action.NONE, [senderId,"Simple message #${counter++}"]));
  }

  //TODO: some more information along with payload?
  _prepareResponse(var message) {
    var ResponseMessage = message[1];
    print("IsolateSystem: Enqueue this response : ${message[1]}");
  }
}
