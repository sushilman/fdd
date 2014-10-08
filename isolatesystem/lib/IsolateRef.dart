library isolatesystem.IsolateRef;

import 'dart:isolate';

import 'action/Action.dart';
import 'message/MessageUtil.dart';
import 'message/SenderType.dart';

class IsolateRef {
  String _name;
  SendPort _isolateSystemSendPort;

  IsolateRef(this._name, this._isolateSystemSendPort);

  send(var message, {IsolateRef replyTo}) {
    // send message to self for enqueuing
    _isolateSystemSendPort.send(MessageUtil.create(SenderType.SELF, null, Action.DONE, {'to': _name, 'message': message, 'replyTo': (replyTo != null) ? replyTo._name : null }));
    //_isolateSystemSendPort.send({'to': _name, 'message': message, 'replyTo': (replyTo != null) ? replyTo._name : null });
    // OR simply enqueue the message to QUEUE of "to" actor?
  }

  // Not used anywhere right now
  /// Bypass queue and send message directly
  sendDirect(var message, {IsolateRef replyTo}) {
    _isolateSystemSendPort.send(MessageUtil.create(SenderType.SELF, null, Action.NONE, {'to': _name, 'message': message, 'replyTo': (replyTo != null) ? replyTo._name : null }));
    //_isolateSystemSendPort.send({'to': _name, 'message': message, 'replyTo': (replyTo != null) ? replyTo._name : null });
  }
}
