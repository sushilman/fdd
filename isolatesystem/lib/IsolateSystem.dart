library isolatesystem.IsolateSystem;

import 'dart:async';
import 'dart:isolate';
import 'dart:convert';
import 'dart:io';

import 'package:uuid/uuid.dart';

import 'action/Action.dart';

import 'message/MessageUtil.dart';
import 'message/SenderType.dart';
import 'message/MQSMessageUtil.dart';

import 'IsolateRef.dart';
import 'controller/Controller.dart';


/**
 * DONE: Take care of these Possible Issues
 * 1. Pull requests are not answered by Message Queuing System
 *  - May be the queue is empty
 *  - may be the pull message does not reach message queuing system
 *  - solution: request again in certain interval... by controller / router ... periodic pull requests?
 *   -- keep track of number of pull requests and number of messages sent to router (by controller)?
 *   -- OR simply keep track of PULL MESSAGES ?
 *   -- OR poll for free isolate if the router is sitting idle for few seconds
 *   -- and send pull request based on that
 *
 *  2. Actor Supervision - Exception escalation? -> Not Done
 *    - how to?
 *      -> onError of Future
 *      -> and, try catch blocks
 *
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
 * {senderType: senderType.controller, id: isolateSystem2/ping, action: action.reply, payload: {sender:isolateSystem2/ping, to: isolateSystem2/pong, message: {value: PING, count: 1}, replyTo: isolateSystem2/ping}}
 * Outgoing message format for MQS
 * {targetQueue: isolateSystem.helloPrinter, action: action.enqueue, payload:{sender:isolateSystem2/ping, to: isolateSystem2/pong, message: {value: PING, count: 1}, replyTo: isolateSystem2/ping}}
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
  String _uniqueId; // should be unique for each instance
  String _name;
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
  IsolateSystem(String this._name, String pathToMQS) {
    this._uniqueId = (new Uuid()).v1();

    _pathToMQS = "$pathToMQS/$_name/$_uniqueId";
    _receivePort = new ReceivePort();
    _me = _receivePort.sendPort;
    _receivePort.listen(_onReceive);
    _connectToMqs();

    _bufferMessagesToController = new List();
    _bufferMessagesToMqs = new List();

    _startController();
  }

  /// if path to router is sent in RouterType, it will be used as the router, it should be absolute uri
  IsolateRef addIsolate(String name, String uri, workersPaths, String routerType, {hotDeployment: true, args}) {
    name = "$_name/$name";
    var message = {'name':name, 'uri':uri, 'workerPaths':workersPaths, 'routerType':routerType, 'hotDeployment':hotDeployment, 'args':args};
    _sendToSelf(MessageUtil.create(SenderType.DIRECT, _name, Action.SPAWN, message));
    return new IsolateRef(name, _me);
  }

  /**
   * After issuing kill command
   * the system gets cleared itself if there are no active connections anywhere
   * including receivePorts and webSockets
   * and no Timers should be running
   */
  void killSystem() {
    _log("KILLALL message");
    _sendToSelf(MessageUtil.create(SenderType.DIRECT, _name, Action.KILL_ALL, null));
    _receivePort.close();
    _mqsSocket.close();
    _isSystemKilled = true;
  }

  void killIsolate(String isolateName) {
    _log("KILL isolate");
    _sendToSelf(MessageUtil.create(SenderType.DIRECT, _name, Action.KILL, {"routerId":isolateName}));
  }

  /**
   * Returns in json format
   */
  Future<String> getRunningIsolates() {
    Completer c = new Completer();
    ReceivePort r = new ReceivePort();
    if(_sendPortOfController == null) {
      c.complete(null);
    } else {
      _sendPortOfController.send([SenderType.ISOLATE_SYSTEM, this.name, Controller.GET_RUNNING_ISOLATES, r.sendPort]); // sendPort:r.sendPort
      r.listen((var msg) {
        print("RUNNing isolates => $msg");
        c.complete(msg);
      });
    }
    return c.future;
  }

  _onReceive(message) {
    _log("IsolateSystem: $message");
    if(message is SendPort) {
      _sendPortOfController = message;
      _flushBufferToController();
    } else if (MessageUtil.isValidMessage(message)) {
      if(message is String) {
        message = JSON.decode(message);
      }

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
      case Action.PULL_MESSAGE:
        _sendToMqs(_prepareDequeueMessage(senderId));
        break;

      case Action.SEND:
      case Action.REPLY:
      case Action.ASK:
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
      case Action.KILL_ALL:
      case Action.NONE:
        _sendToController(message);
        break;
      default:
        _log("IsolateSystem: (Direct Message Handler): Unknown Action -> $action");
    }
  }

  _startController() {
    Isolate.spawn(controller, {'id':"controller", 'sendPort':_me});
  }

  _connectToMqs() {
    if(!_isSystemKilled) {
      WebSocket.connect(_pathToMQS).then(_handleMqsWebSocket).catchError(_onErrorFromMqs);
    }
  }

  _handleMqsWebSocket(WebSocket socket) {
    _log("Connected to mqs!");
    _mqsSocket = socket;
    _mqsSocket.listen(_onDataFromMqs, onDone:_onDisconnectedFromMqs);
    _flushBufferToMqs();
  }

  _onErrorFromMqs(var message) {
    _log("Error while connecting to MQS");
    new Timer(new Duration(seconds:3), () {
      _log("Retrying...");
      _connectToMqs();
    });
  }

  _onDisconnectedFromMqs() {
    new Timer(new Duration(seconds:3), () {
      _log("Retrying...");
      _connectToMqs();
    });
  }



  /**
   * Incoming Message from MQS:
   * {senderType: senderType.dequeuer, topic: isolateSystem2.pong, payload: {message: {value: PING, count: 267}, replyTo: isolateSystem2/ping}}
   *
   * Outgoing Message to IsolateSystem:
   * {senderType: senderType.mqs, id: isolateSystem2,
   *  action: action.none,
   *  payload: {to: isolateSystem2/pong,
   *            message: {message: {value: PING, count: 267},
   *            replyTo: isolateSystem2/ping}}}
   */
  _onDataFromMqs(var data) {
    var decodedData = JSON.decode(data);
    _log("Message Arrived from MQS: ${decodedData}");
    String topic = decodedData['topic'];
    //String isolateName = topic.split('.').last;
    String isolateId = topic.replaceAll('.','/');

    Map payload = {'to':isolateId, 'message':decodedData['payload']};

    _sendToSelf(MessageUtil.create(SenderType.MQS, _name, Action.NONE, payload));
  }

  /**
   * prepares a dequeue message to send to MessageQueuingSystem over websocket connection
   */
  _prepareDequeueMessage(String senderId) {
    String sourceIsolate = _getQueueFromIsolateId(senderId);
    Map dequeueMessage = MQSMessageUtil.createDequeueMessage(sourceIsolate);
    _log("PULL MESSAGE $dequeueMessage");
    return dequeueMessage;
  }

  /*
   * In case the of ASK
   * add vm_id / isolateSystem's unique id
   */
  _prepareEnqueueMessage(Map message) {
    _log("Preparing enqueue message: $message");
    message = message['payload'];
    String targetIsolate = (message.containsKey('to')) ? message['to'] : null;

    if(targetIsolate != null) {
      String sender = (message['sender']);
      String replyTo = (message.containsKey('replyTo')) ? message['replyTo'] : null;
      String msg = (message['message']);

      var payload = {'sender':sender, 'message':msg, 'replyTo':replyTo};

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
    int len = _bufferMessagesToMqs.length;
    for(int i = 0; i < len; i++) {
      _sendToMqs(_bufferMessagesToMqs.removeAt(0));
    }
  }

  /**
   * Converting to JSON
   */
  _sendToController(var message) {
    message = MessageUtil.setSenderType(SenderType.ISOLATE_SYSTEM, message);

    if(_sendPortOfController != null) {
      _log("sending via sendport: $message");
      _sendPortOfController.send(JSON.encode(message));
    } else {
      _log("Sending to buffer : $message");
      _bufferMessagesToController.add(message);
    }
  }

  _sendToSelf(var message) {
    _me.send(JSON.encode(message));
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
    _log("Exception caught by IsolateSystem $e");
  }

  _log(String text) {
    //print(text);
  }

  String get name => _name;
  set name(String value) => _name = value;

  String get uniqueId => _uniqueId;
  set uniqueId(String value) => _uniqueId = value;

  String get pathToMQS => _pathToMQS;
  set pathToMQS(String value) => _pathToMQS = value;
}
