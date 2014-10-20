library isolatesystem.IsolateRef;

import 'dart:isolate';

import 'action/Action.dart';
import 'message/MessageUtil.dart';
import 'message/SenderType.dart';

class IsolateRef {
  String _name;
  SendPort _isolateSystemSendPort;

  IsolateRef(this._name, this._isolateSystemSendPort);

  send(var msg, {IsolateRef replyTo}) {
    //Map message = {'message':msg, 'replyTo': (replyTo != null) ? replyTo._name : null};
    // send message to self for enqueuing
    _isolateSystemSendPort.send(MessageUtil.create(SenderType.SELF, null, Action.DONE, {'to': _name, 'message': msg, 'replyTo': (replyTo != null) ? replyTo._name : null}));
    //_isolateSystemSendPort.send({'to': _name, 'message': message, 'replyTo': (replyTo != null) ? replyTo._name : null });
    // OR simply enqueue the message to QUEUE of "to" actor?
  }

  // Not used anywhere
  /// Bypass queue and send message directly
  sendDirect(var msg, {IsolateRef replyTo}) {
    Map message = {'message':msg, 'replyTo': (replyTo != null) ? replyTo._name : null};
    _isolateSystemSendPort.send(MessageUtil.create(SenderType.DIRECT, null, Action.NONE, {'to': _name, 'message': message}));
    //_isolateSystemSendPort.send({'to': _name, 'message': message, 'replyTo': (replyTo != null) ? replyTo._name : null });
  }
}
