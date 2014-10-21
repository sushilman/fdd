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
 * Outgoing message format to controller : {}
 *
 * Incoming message from Controller :
 * {senderType: senderType.controller, id: isolateSystem2/ping, action: action.pull, payload: null}
 * Outgoing message format for MQS :
 * {targetQueue: isolateSystem2.ping, action: action.dequeue}
 *
 * Incoming message from Controller:
 * {senderType: senderType.controller, id: isolateSystem2/ping, action: action.reply, payload: {to: isolateSystem2/pong, message: {value: PING, count: 1}, replyTo: isolateSystem2/ping}}
 * Outgoing message format for MQS
 *
 */

/**
 * Messages can arrive from:
 *  1. MQS
 *  2. CONTROLLER
 *  3. DIRECT via IsolateRef
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
    _me.send(MessageUtil.create(SenderType.DIRECT, _id, Action.SPAWN, message));
    return new IsolateRef(name, _me);
  }

  /**
   * After issuing kill command
   * the system gets cleared itself if there are no active connections anywhere
   * including receivePorts and webSockets
   * and no Timers should be running
   */
  void kill() {
    print("KILL message");
    _me.send(MessageUtil.create(SenderType.DIRECT, _id, Action.KILL, null));
    _receivePort.close();
    _mqsSocket.close();
    _isSystemKilled = true;
  }

  _onReceive(message) {
    _log("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
      _flushBufferToController();
    } else if (MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      switch(senderType) {
        case SenderType.CONTROLLER:
          _handleMessageFromController(message);
          break;
        case SenderType.MQS:
          _handleMessageFromMQS(message);
          break;
        case SenderType.DIRECT:
          _handleDirectMessage(message);
          break;
        default:
          _log("IsolateSystem: Unknown Sender");
      }
    } else if (message is Exception) {
      _handleException(message);
    } else {
      _log("IsolateSystem: Unknown message: $message");
    }
  }

  /**
   * Handle message arriving from MessageQueuingSystem
   * i.e. Dequeued Messages
   */
  _handleMessageFromMQS(var message) {
    _sendToController(message);
  }

  /**
   * Handle message that controller sends
   *   * SEND,ASK,REPLY - Enqueue Message
   *   * PULL_MESSAGE - a Pull Request for new message
   */
  _handleMessageFromController(var message) {
    String senderType = MessageUtil.getSenderType(message);
    String senderId = MessageUtil.getId(message);
    String action = MessageUtil.getAction(message);
    var payload = MessageUtil.getPayload(message);

    switch(action) {
      case Action.DONE:
      case Action.PULL_MESSAGE:
        _sendToMqs(_pullMessage(senderId));
        break;
      case Action.SEND:
      case Action.ASK:
      case Action.REPLY:
        _sendToMqs(_prepareEnqueueMessage(message));
        break;
      default:

    }
  }

  /**
   * Handle messages send directly via bootstrapper
   *   * SPAWN - add isolate
   *   * KILL - kill the isolateSystem
   *   * NONE - a simple message that bypasses MQS
   */
  _handleDirectMessage(var message) {
    String action = MessageUtil.getAction(message);
    switch(action) {
      case Action.SPAWN:
      case Action.KILL:
      case Action.NONE:
        _sendToController(message);
        break;
      default:
        print("IsolateSystem: (Direct Message Handler): Unknown Action -> $action");
    }
  }

  _startController() {
    String curDir = dirname(Platform.script.toString());
    String controllerUri = curDir + "/packages/isolatesystem/controller/Controller.dart";
    Isolate.spawnUri(Uri.parse(controllerUri), ["controller"], _receivePort.sendPort)
    .then((controller) {
      _controllerIsolate = controller;
      controller.errors.handleError((_){_log("error handled");});
    });
  }

  _connectToMqs(String path) {
    if(!_isSystemKilled) {
      WebSocket.connect(path).then(_handleMqsWebSocket).catchError((_) {
        new Timer(new Duration(seconds:3), () {
          _log("Retrying...");
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
    _log("Message Arrived from MQS: ${decodedData}");
    String topic = decodedData['topic'];
    String isolateName = topic.split('.').last;
    String isolateId = topic.replaceAll('.','/');
    Map payload = {'to':isolateId, 'message':decodedData['message']};

    _me.send(MessageUtil.create(SenderType.MQS, _id, Action.NONE, payload));
  }

  /**
   * prepares a pulls message from MessageQueuingSystem over websocket connection
   */
  _pullMessage(String senderId) {
    String sourceIsolate = _getQueueFromIsolateId(senderId);
    Map dequeueMessage = MQSMessageUtil.createDequeueMessage(sourceIsolate);
    _log("PULL MESSAGE $dequeueMessage");
    return dequeueMessage;
  }

  _prepareEnqueueMessage(Map message) {
    _log("Preparing enqueu message from ... $message");
    message = message['payload'];
    String targetIsolate = (message.containsKey('to')) ? message['to'] : null;

    if(targetIsolate != null) {
      String replyTo = (message.containsKey('replyTo')) ? message['replyTo'] : null;
      String msg = (message['message']);
      var payload = {'message':msg, 'replyTo':replyTo};

      String targetQueue = _getQueueFromIsolateId(targetIsolate);
      return MQSMessageUtil.createEnqueueMessage(targetQueue, payload);
    }
    return null;
  }

  _flushBufferToController() {
    int len = _bufferMessagesToController.length;
    for(int i = 0; i < len; i++) {
      _sendToController(_bufferMessagesToController.removeAt(0));
    }
  }

  _flushBufferToMqs() {
    int len = _bufferMessagesToController.length;
    for(int i = 0; i < len; i++) {
      _sendToMqs(_bufferMessagesToMqs.removeAt(0));
    }
  }

  _sendToController(var message) {
    message = MessageUtil.setSenderType(SenderType.ISOLATE_SYSTEM, message);

    if(_sendPortOfController != null) {
      print("sending via sendport: $message");
      _sendPortOfController.send(message);
    } else {
      print("Sending to buffer : $message");
      _bufferMessagesToController.add(message);
    }
  }

  _forward(var message) {

  }

  _sendToMqs(var message) {
    if(message == null) {
      throw StackTrace;
    }
    if(_mqsSocket != null) {
      _mqsSocket.add(JSON.encode(message));
    } else {
      _bufferMessagesToMqs.add(message);
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

  _log(String text) {
    print(text);
  }

  String get id => _id;
  set id(String value) => _id = value;

  String get pathToMQS => _pathToMQS;
  set pathToMQS(String value) => _pathToMQS = value;
}
