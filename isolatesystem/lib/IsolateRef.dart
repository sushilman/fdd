library isolatesystem.IsolateRef;

import 'dart:async';
import 'dart:isolate';

import 'action/Action.dart';
import 'message/MessageUtil.dart';
import 'message/SenderType.dart';

class IsolateRef {
  String name;
  SendPort isolateSystemSendPort;

  IsolateRef(this.name, this.isolateSystemSendPort);

  send(var message) {
    isolateSystemSendPort.send(MessageUtil.create(SenderType.EXTERNAL, null, Action.NONE, [name, message]));
  }
}
