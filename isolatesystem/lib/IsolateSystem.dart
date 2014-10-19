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
import 'message/MQSMessageUtil.dart';

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
 * Oct 15:
 * If an isolateSystem is started by a bootstrapper which maintains connection with Registry
 * Send queries to registry (like get queuetopic from isolatename) via same connection ?
 *
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

/**
 * payload = "Hello World"
 * Incoming message format : {'senderType' : sender.External, 'id' : <id_of_sender>, 'action': Action.NONE, 'payload' : "Hello World"}
 *
 * Incoming message from MQS: {}
 * Incoming message from Controller : {}
 *
 * Outgoing message format to controller : {}
 * Outgoing message format for MQS : {}
 */

/**
 * Messages from :
 *  1. MQS
 *  2. CONTROLLER
 *
 */
class IsolateSystem {
  ReceivePort _receivePort;
  SendPort _sendPortOfController;
  SendPort _me;
  String _id;
  bool _isSystemKilled = false;

  Isolate _controllerIsolate;
  bool _hotDeployment = false;

  String _workerUri;

  int counter = 0;

  String _pathToMQS;
  WebSocket _mqsSocket;

  List _bufferMessagesToController;
  List _bufferMessagesToMqs;

  /// @name - Name of this isolate system
  IsolateSystem(String this._id, String pathToMQS) {
    _pathToMQS = "$pathToMQS/$_id";
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _connectToMqs(_pathToMQS);

    _bufferMessagesToController = new List();
    _bufferMessagesToMqs = new List();

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

  /**
   * After issuing kill command
   * the system gets cleared itself if there are no active connections anywhere
   * including receivePorts and webSockets
   * and no Timers should be running
   */
  void kill(IsolateSystem system) {
    //_sendPortOfController.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.KILL, null));
    _me.send(MessageUtil.create(SenderType.ISOLATE_SYSTEM, _id, Action.KILL, null));
    _receivePort.close();
    _isSystemKilled = true;
    system = null;
  }

  _onReceive(message) {
    _out("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
      _flushBufferToController();
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
      _out("IsolateSystem: Unknown message: $message");
    }
  }

  _handleMessagesFromController(String senderId, String action, var payload, var fullMessage) {
    switch (action) {
      case Action.CREATED:
      case Action.PULL_MESSAGE:
        if(_mqsSocket != null)
          _pullMessage(senderId);
        else
          _bufferMessagesToMqs.add(fullMessage);
          //_me.send(fullMessage);
        break;
      case Action.REPLY:
        if(_mqsSocket != null) {
          if (payload != null) {
            _enqueueResponse(payload);
          }
        } else {
          _bufferMessagesToMqs.add(fullMessage);
          //_me.send(fullMessage);
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
      //_me.send(fullMessage);
      _bufferMessagesToController.add(fullMessage);
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
          if(_mqsSocket != null) {
            if (payload != null) {
              _enqueueResponse(payload);
            }
          } else {
            _bufferMessagesToMqs.add(fullMessage);
            //_me.send(fullMessage);
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
    if(!_isSystemKilled) {
      WebSocket.connect(path).then(_handleMqsWebSocket).catchError((_) {
        new Timer(new Duration(seconds:3), () {
          _out("Retrying...");
          _connectToMqs(path);
        });
      });
    }
  }

  _handleMqsWebSocket(WebSocket socket) {
    _mqsSocket = socket;
    _mqsSocket.listen(_onDataFromMqs);
    _flushBufferToMqs();
  }

  _onDataFromMqs(var data) {
    var decodedData = JSON.decode(data);
    _out("Message Arrived from MQS: ${decodedData}");
    String topic = decodedData['topic'];
    String isolateName = topic.split('.').last;
    String isolateId = topic.replaceAll('.','/');
    Map payload = {'to':isolateId, 'message':decodedData['message']};

    _me.send(MessageUtil.create(SenderType.SELF, _id, Action.NONE, payload));
  }

  /**
   * Pulls message from MessageQueuingSystem over websocket connection
   */
  _pullMessage(String senderId) {
    print("PULL MESSAGE by $senderId");
    String sourceIsolate = _getQueueFromIsolateId(senderId);
    Map dequeueMessage = MQSMessageUtil.createDequeueMessage(sourceIsolate);
    _mqsSocket.add(JSON.encode(dequeueMessage));
  }

  _enqueueResponse(Map message) {
    String targetIsolate = (message.containsKey('to')) ? message['to'] : null;

    if(targetIsolate != null) {
      String replyTo = (message.containsKey('replyTo')) ? message['replyTo'] : null;
      String msg = (message['message']);
      var payload = {'message':msg, 'replyTo':replyTo};

      String targetQueue = _getQueueFromIsolateId(targetIsolate);
      var enqueueMessage = MQSMessageUtil.createEnqueueMessage(targetQueue, payload);
      _mqsSocket.add(JSON.encode(enqueueMessage));
    }
  }

  _flushBufferToController() {
    for(var msg in _bufferMessagesToController) {
      _me.send(msg);
    }
  }

  _flushBufferToMqs() {
    for(var msg in _bufferMessagesToMqs) {
      _me.send(msg);
    }
  }

  /**
   * TODO:
   * Send Request to Registry and get queue-topic
   * (may be store it locally too?)
   */
  _getQueueFromIsolateId(String isolateId) {
    return isolateId.replaceAll('/', '.');
  }

  _getIsolateIdFromQueue(String queue) {
    return queue.replaceAll('.', '/');
  }

  void _handleException(e) {
    print("Exception caught by IsolateSystem $e");
  }

  _out(String text) {
    print(text);
  }

  String get id => _id;
  set id(String value) => _id = value;

  String get pathToMQS => _pathToMQS;
  set pathToMQS(String value) => _pathToMQS = value;
}
