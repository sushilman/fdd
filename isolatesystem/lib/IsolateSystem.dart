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
import 'IsolateRef.dart';

/**
 * TODO: Take care of theses Possible Issues
 * 1. Pull requests are not answered by Message Queuing System
 *  - May be the queue is empty
 *  - may be the pull message does not reach message queuing system
 *  - solution: request again in certain interval... by controller / router ... periodic pull requests?
 *   -- keep track of number of pull requests and number of messages sent to router from controller?
 *   -- OR simply keep track of PULL MESSAGES ?
 *   -- OR poll for free isolate if the router is sitting idle for few seconds
 *   -- and send pull request based on that
 * 2.
 */

/**
 * Message Structure:
 * [0] -> Message From <Type> - type: isolate system, controller, router, worker
 * [1] -> ID
 * [2] -> Action
 * [3] -> message -> can be String or List
 */

/**
 * Controller sends a pull request
 * after which, a message is fetched using messageQueuingSystem
 * from appropriate queue and sent to the controller
 */
class IsolateSystem {
  ReceivePort _receivePort;
  SendPort _sendPortOfController;
  SendPort _me;
  String _id;
  bool _isSystemReady = false;

  Isolate _controllerIsolate;
  bool _hotDeployment = false;

  List<Map> _bufferedMessages;

  String _workerUri;

  int counter = 0;

  var completer;

  /// @name - Name of this isolate system
  IsolateSystem(String name) {
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _id = name;

    _bufferedMessages = new List<Map>();
    _startController();
  }

  /// if path to router is sent in RouterType, it will be used as the router, it should be absolute uri
  IsolateRef addIsolate(String name, String uri, workersPaths, String routerType, {hotDeployment: true, args}) {
    String routerUri = routerType;
    completer = new Completer();
    if(routerType == Router.RANDOM) {
      routerUri = "../router/Random.dart";
    }

    var message = {'name':name, 'uri':uri, 'workerPaths':workersPaths, 'routerUri':routerUri, 'hotDeployment':hotDeployment, 'args':args};
    if(_sendPortOfController == null) {
      print("Waiting for controller to be ready");
      _bufferedMessages.add(MessageUtil.create(SenderType.SELF, _id, Action.ADD, message));
    } else {
      _me.send(MessageUtil.create(SenderType.SELF, _id, Action.ADD, message));
    }

    return new IsolateRef(name, _me);
  }

  _onReceive(message) {
    print("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
      if(!_bufferedMessages.isEmpty) {
        _bufferedMessages.forEach((message) {
          _me.send(message);
        });
        _bufferedMessages.clear();
      }
    } else if (MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);

      if (senderType == SenderType.CONTROLLER) {
        _handleMessagesFromController(senderId, action, payload);
      } else if (senderType == SenderType.SELF){
        _handleOtherMessages(action, payload, senderType, message);
      } else {
        _handleExternalMessages(message);
      }
    } else {
      _handleExternalMessages(message);
      print ("IsolateSystem: Unknown message: $message");
    }
  }

  _handleMessagesFromController(String senderId, String action, var payload) {
    switch (action) {
      case Action.CREATED:
      case Action.PULL_MESSAGE:
        _pullMessage(senderId);
        break;
      case Action.REPLY:
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

  _handleOtherMessages(action, payload, senderType, fullMessage) {
    if(_sendPortOfController == null) {
      _bufferedMessages.add(fullMessage);
    } else {
      switch (action) {
        case Action.ADD:
          print("IsolateSystem: ADD action with $payload");
          _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.SPAWN, payload));
          break;
        case Action.NONE:
          _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.NONE, payload));
          break;
        case Action.DONE:
          if(payload != null) {
            _prepareResponse(payload);
          }
          break;
        default:
          print("IsolateSystem: Unknown Sender: $senderType");
      }
    }
  }

  _handleExternalMessages(var message) {
    _me.send(MessageUtil.create(SenderType.SELF, _id, Action.NONE, message));
  }

  _startController() {
    String curDir = dirname(Platform.script.toString());
    String controllerUri = curDir + "/packages/isolatesystem/controller/Controller.dart";
    Isolate.spawnUri(Uri.parse(controllerUri), ["controller"], _receivePort.sendPort)
    .then((controller) {
      _controllerIsolate = controller;
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
    // send message to self once message arrives from Message Queuing System
    //var sendMsg = {'to': senderId, 'message': [9, counter++]};
    //_me.send(MessageUtil.create(SenderType.SELF, _id, Action.NONE, sendMsg));
  }

  _prepareResponse(var message) {
    print("IsolateSystem: Enqueue this response to '${message['to']}': '${message['message']}' with replyTo '${message['replyTo']}'");

    // Assume the message is enqueued.. and dequeued
    // To emulate
    // simply call dequeue function here
  }


}
