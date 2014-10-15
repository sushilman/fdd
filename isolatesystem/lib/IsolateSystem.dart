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
 * TODO: Take care of these Possible Issues
 * 1. Pull requests are not answered by Message Queuing System
 *  - May be the queue is empty
 *  - may be the pull message does not reach message queuing system
 *  - solution: request again in certain interval... by controller / router ... periodic pull requests?
 *   -- keep track of number of pull requests and number of messages sent to router (by controller)?
 *   -- OR simply keep track of PULL MESSAGES ?
 *   -- OR poll for free isolate if the router is sitting idle for few seconds
 *   -- and send pull request based on that
 *
 *  2. Actor Supervision - Exception escalation?
 *    - how to?
 *      -> onError of Future
 *      -> and, try catch blocks
 *
 * TODO: Refactor Actions in isolateSystem,Controller,Routers, Workers
 *
 * TODO: Isolate namings are probably okay because there will be registry
 * TODO: which will be resolving queueName for us from systemid+isolateId
 * TODO:
 */

/**
 * Controller sends a pull request
 * after which, a message is fetched using messageQueuingSystem
 * from appropriate queue and sent to the controller
 *
 *
 * Path to message queueing system should be sent by registry while initializing an isolateSystem
 * Registry simply sends Add isolate request
 * So, if an isolate system is already running, and if the path for MQS sent is different from existing,
 * then new connection string shall be ignored
 *
 */

class IsolateSystem {
  ReceivePort _receivePort;
  SendPort _sendPortOfController;
  SendPort _me;
  String _id;
  bool _isSystemReady = false;

  Isolate _controllerIsolate;
  bool _hotDeployment = false;

  String _workerUri;

  int counter = 0;

  String _pathToMQS;
  WebSocket _mqsSocket;

  /// @name - Name of this isolate system
  IsolateSystem(String this._id, String pathToMQS) {
    _pathToMQS = "$pathToMQS/$_id";
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _connectToMqs(_pathToMQS);

    _startController();
  }

  /// if path to router is sent in RouterType, it will be used as the router, it should be absolute uri
  IsolateRef addIsolate(String name, String uri, workersPaths, String routerType, {hotDeployment: true, args}) {
    name = "$_id/$name";
    String routerUri = routerType;

    switch(routerType) {
      case Router.RANDOM:
        routerUri = "../router/Random.dart";
        break;
      case Router.ROUND_ROBIN:
        routerUri = "../router/RoundRobin.dart";
        break;
      case Router.BROADCAST:
        routerUri = "../router/BroadCast.dart";
        break;
      default:
    }

    var message = {'name':name, 'uri':uri, 'workerPaths':workersPaths, 'routerUri':routerUri, 'hotDeployment':hotDeployment, 'args':args};
    _me.send(MessageUtil.create(SenderType.SELF, _id, Action.ADD, message));
    return new IsolateRef(name, _me);
  }

  _onReceive(message) {
    _out("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
    } else if (MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);

      if (senderType == SenderType.CONTROLLER) {
        _handleMessagesFromController(senderId, action, payload, message);
      } else if (senderType == SenderType.SELF){
        _handleOtherMessages(action, payload, senderType, message);
      } else {
        _handleExternalMessages(message);
      }
    } else if (message is Exception) {
      _handleException(message);
    } else {
      _handleExternalMessages(message);
      print ("IsolateSystem: Unknown message: $message");
    }
  }

  _handleMessagesFromController(String senderId, String action, var payload, var fullMessage) {
    switch (action) {
      case Action.CREATED:
      case Action.PULL_MESSAGE:
        if(_mqsSocket != null)
          _pullMessage(senderId);
        else
          _me.send(fullMessage);
        break;
      case Action.REPLY:
        if(payload != null) {
          _enqueueResponse(payload);
        }
        break;
      case Action.RESTART_ALL:
        _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.RESTART_ALL, payload));
        break;
      default:
        _out("IsolateSystem: Unknown Action: $action");
    }
  }

  _handleOtherMessages(action, payload, senderType, fullMessage) {
    if(_sendPortOfController == null) {
      _me.send(fullMessage);
    } else {
      switch (action) {
        case Action.ADD:
          _out("IsolateSystem: ADD action with $payload");
          _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.SPAWN, payload));
          break;
        case Action.NONE:
          _sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.NONE, payload));
          break;
        case Action.DONE:
          if(payload != null) {
            _enqueueResponse(payload);
          }
          break;
        default:
          _out("IsolateSystem: Unknown Sender: $senderType");
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
      controller.errors.handleError((_){_out("error handled");});
    });
  }

  _connectToMqs(String path) {
    WebSocket.connect(path).then(_handleMqsWebSocket).catchError((_){
      new Timer(new Duration(seconds:3), () {
        print ("Retrying...");
        _connectToMqs(path);
      });
    });
  }

  _handleMqsWebSocket(WebSocket socket) {
    _mqsSocket = socket;
    _mqsSocket.listen(_onDataFromMqs);

    /**
     * Sending dequeue messages on connection
     * JUST for testing MQS connection
     * Send dequeue messages to MQS that arrive from controller, with proper message format
     */
//    new Timer.periodic (const Duration(seconds:5), (t) {
//      Map message = {'isolateName':"helloPrinter", 'action':"action.dequeue"};
//      socket.add(JSON.encode(message));
//      print("\n\n\nRequest sent: ");
//    });
  }

  _onDataFromMqs(var data) {
    var decodedData = JSON.decode(data);
    print("Message Arrived from MQS: ${decodedData}");
    String topic = decodedData['topic'];
    String isolateName = topic.split('.').last;
    String isolateId = topic.replaceAll('.','/');
    Map payload = {'to':isolateId, 'message':decodedData['message']};

    _me.send(MessageUtil.create(SenderType.SELF, _id, Action.NONE, payload));
    //_me.send(message);
  }

  /**
   * Pulls message from MessageQueuingSystem over websocket connection
   */
  _pullMessage(String senderId) {
    senderId = senderId.split('/').last;
    Map dequeueMessage = {'isolateName':senderId, 'action':"action.dequeue"};
    //Map message = {'isolateName':"helloPrinter", 'action':Mqs.DEQUEUE};
    print("Request String: ${JSON.encode(dequeueMessage)}");
    _mqsSocket.add(JSON.encode(dequeueMessage));

    // TODO: pull message from appropriate queue from MessageQueuingSystem
    // something like messageQueuingSystem.send(message)
    // then send to sendPort of controller
    // sendPort.send(newMessage);
    //
    // send message to self once message arrives from Message Queuing System
    //var sendMsg = {'to': senderId, 'message': [9, counter++]};
    //_me.send(MessageUtil.create(SenderType.SELF, _id, Action.NONE, sendMsg));
  }

  _enqueueResponse(Map message) {
    // set target to 'this' system if targetIsolateSystemId is not set and if target isolate exists in current system?
    // or simply make the developers use "isolatesystem/poolname" name scheme
    print("IsolateSystem: Enqueue String -> $message");
    String targetSystem = (message.containsKey('targetIsolateSystemId')) ? message['targetIsolateSystemId'] : this._id;
    String isolateName = (message.containsKey('to')) ? message['to'] : null;
    String replyTo = (message.containsKey('replyTo')) ? message['replyTo'] : null;
    String msg = (message['message']);

    var enqueueMessage = JSON.encode({'targetIsolateSystemId':targetSystem, 'isolateName':isolateName, 'action':"action.enqueue", 'payload':{'message':msg, 'replyTo':replyTo}});
    // Assume the message is enqueued.. and dequeued
    // To emulate
    // simply call dequeue function here
    //sleep(const Duration(seconds:1));

    //_onData(message); /* emulating async call over websocket */
    if(isolateName != null) {
      _mqsSocket.add(enqueueMessage);
    }
  }

  /**
   * On data received from WebSocket (of MessageQueuingSystem)
   */
  _onData(var message) {
    _me.send(message);
  }

  void _handleException(e) {
    print ("Exception caught by IsolateSystem $e");
  }

  _out(String text) {
    print(text);
  }

  String get id => _id;
  set id(String value) => _id = value;

  String get pathToMQS => _pathToMQS;
  set pathToMQS(String value) => _pathToMQS = value;
}
