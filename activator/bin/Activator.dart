import 'dart:io';
import 'dart:isolate';
import 'dart:convert';

import 'package:isolatesystem/IsolateSystem.dart';
import 'package:isolatesystem/action/Action.dart';
import 'package:isolatesystem/message/MessageUtil.dart';
import 'package:isolatesystem/message/SenderType.dart';

import 'WebSocketServer.dart';
/*
 * Web socket handler
 *
 * Keeps on listening to any incoming websocket connections
 * Can handle multiple simultaneous connections (don't think it is significant?)
 *
 * Default address is ws://<ip>:42042/activator
 *
 * Spawns isolates that are in the vm where activator is running
 * or spawns an (controller?) isolate for a physical vm
 *
 * How to separate between physical vm and logical system
 * The activator itself can be the central isolate
 *
 *
 * ------------
 * Router of an isolate system will request the activator to spawn isolates
 * So an activator has to:
 *  1. Spawn an isolate
 *  2. Kill/ping an isolate
 *  3. Forward messages to proper isolate
 *
 * //Make Activator must be robust. Have to continue running, should not shutdown because of some exception !
 */

/**
 * Connect to Registry and get data from it
 */

class Activator {
  ReceivePort receivePort;
  List<_Isolate> isolates;

  WebSocketServer wss;

  static String defaultPath = "/activator";
  static int defaultPort = 42043;

  Activator() {
    isolates = new List<_Isolate>();
    receivePort = new ReceivePort();
    receivePort.listen(_onReceive, onError:_onErrorDuringListening);

    listenOn(defaultPort, defaultPath);

    Isolate.spawnUri(Uri.parse("SystemBootstrapper.dart"), ["ws://localhost:42044/registry"], receivePort.sendPort);
  }

  /**
   * Assumes that evey isolate this Activator is going to spawn
   * will send id along with its send port
   */
  _onReceive(var message) {
    print("Activator: message received from isolate -> $message");

    if(MessageUtil.isValidMessage(message)) {
      String senderType = MessageUtil.getSenderType(message);
      String senderId = MessageUtil.getId(message);
      String action = MessageUtil.getAction(message);
      var payload = MessageUtil.getPayload(message);

      switch(senderType) {
        case SenderType.SELF:
        case SenderType.WORKER:
          _handleMessageFromWorker(message, senderType, senderId, action, payload);
          break;
      }
    }
  }

  _handleMessageFromWorker(String message, String senderType, String senderId, String action, var payload) {
    _Isolate worker = getIsolateById(senderId);
    if(worker != null) {
      switch (action) {
        case Action.CREATED:
          worker.sendPort = payload;
          worker.socket.add(JSON.encode(MessageUtil.create(senderType, senderId, action, null)));
          break;
        case Action.REPLY:
        case Action.DONE:
          worker.socket.add(JSON.encode(message));
          break;
        case Action.NONE:
          worker.socket.add(JSON.encode(message));
          break;
        default:
          print("Activator: Unknown action -> $action");
          worker.socket.add(JSON.encode(message));
      }
    } else {
      print("Activator: No active connections");
    }
  }

  _onErrorDuringListening(message) {

  }

  /*
   * Listen on a websocket address
   */
  void listenOn(int port, String path) {
    wss = new WebSocketServer(port, path, _onConnect, _onData, _onDisconnect);
  }

  _onConnect(WebSocket socket) {

  }

  _onDisconnect(WebSocket socket) {
    isolates.remove(_getWorkerBySocket(socket));
    socket.close();
  }

  // message from Proxy via websocket
  _onData(WebSocket socket, var msg) {
    var message = JSON.decode(msg);
    print("Activator: Received via websocket $message");
    String senderType = MessageUtil.getSenderType(message);
    String senderId = MessageUtil.getId(message);
    String action = MessageUtil.getAction(message);
    String payload = MessageUtil.getPayload(message);

    //print("Inside onData: ${senderId}");

    switch(action) {
      case Action.SPAWN:
        String poolName = payload[0];
        String uri = payload[1];
        String path = payload[2];
        var extraArgs = payload[3];
        List<String> args = [senderId, poolName, path, extraArgs];
        _spawnWorker(uri, args, socket);
        break;
      case Action.RESTART:
      case Action.NONE:
        _forward(senderId, message);
        break;
      default:
        print("Activator: Unknown action -> $action");
    }
  }

  _spawnWorker(String uri, List<String> args, WebSocket socket) {
    Isolate.spawnUri(Uri.parse(uri), args, receivePort.sendPort).then((isolate) {
      isolates.add(new _Isolate(args[0], isolate, socket));
    }, onError:((message) {
        onErrorDuringSpawn(socket, message);
    }));
  }

  onErrorDuringSpawn(WebSocket socket, var message) {
    print("Error: could not spawn isolate. Reason: $message");
    socket.add(JSON.encode([Action.ERROR, "Reason: $message"]));
  }

  _forward(String id, var message) {
    getIsolateById(id).sendPort.send(message);
  }

  _Isolate getIsolateById(String id) {
    for(_Isolate isolate in isolates) {
      if(isolate.id == id) {
        return isolate;
      }
    }
    return null;
  }

  _getWorkerBySocket(WebSocket socket) {
    for(_Isolate isolate in isolates) {
      if(isolate.socket == socket) {
        return isolate;
      }
    }
    return null;
  }
}

void main() {
  new Activator();
}

class _Isolate {
  String _id;
  SendPort _sendPort;
  Isolate _isolate;
  WebSocket _socket;

  _Isolate(this._id, this._isolate, this._socket);

  set sendPort(SendPort value) => _sendPort = value;
  SendPort get sendPort => _sendPort;

  set isolate(Isolate value) => _isolate = value;
  Isolate get isolate => _isolate;

  set id(String value) => _id = value;
  String get id => _id;

  WebSocket get socket => _socket;
  set socket(WebSocket value) => _socket = value;

}
