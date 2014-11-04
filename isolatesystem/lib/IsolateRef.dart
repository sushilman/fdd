library isolatesystem.IsolateRef;

import 'dart:isolate';

import 'action/Action.dart';
import 'message/MessageUtil.dart';
import 'message/SenderType.dart';

class IsolateRef {
  String _name;
  SendPort _isolateSystemSendPort;

  IsolateRef(this._name, this._isolateSystemSendPort);

  /// Send message via queue
  send(var msg, {IsolateRef replyTo}) {
    _isolateSystemSendPort.send(MessageUtil.create(SenderType.CONTROLLER, null, Action.SEND, {'sender':'none','to': _name, 'message': msg, 'replyTo': (replyTo != null) ? replyTo._name : null}));
  }

  /// Bypass queue and send message directly
  sendDirect(var msg, {IsolateRef replyTo}) {
    Map message = {'message':msg, 'replyTo': (replyTo != null) ? replyTo._name : null};
    _isolateSystemSendPort.send(MessageUtil.create(SenderType.DIRECT, null, Action.NONE, {'to': _name, 'message': message}));
  }
}
