import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "message/MessageUtil.dart";

String topic = "isolateSystem.helloPrinter";
var message = MessageUtil.createDequeueMessage(topic);
WebSocket socket;
void main() {
  WebSocket.connect("ws://localhost:42043/mqs/isolateSystem/dummyUuid").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket ws) {
  socket = ws;
  ws.listen(_onData);
  if(ws.readyState == WebSocket.OPEN) {
      _dequeueMsg();
  }
}

_onData(var message) {
  _dequeueMsg();
}

_dequeueMsg() {
  socket.add(JSON.encode(message));
}

_onError() {

}
