import 'dart:io';
import 'dart:convert';
import 'dart:async' show Timer;

import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "Mqs.dart";

class Test {
  Test() {
  }
}

void main() {
  WebSocket.connect("ws://localhost:42043/mqs/anySystem").then(_handleWebSocket).catchError(_onError);
}

_handleWebSocket(WebSocket socket) {
  socket.listen(_onData, onError:_onError, onDone:_onDisconnect);
  int counter = 0;
  new Timer.periodic (const Duration(seconds:0.001), (t) {
    Map message = {'targetIsolateSystemId':'isolateSystem', 'to':"helloPrinter", 'message':"My message #${counter++}", 'replyTo':'helloPrinter2'};

    String targetSystem = (message.containsKey('targetIsolateSystemId')) ? message['targetIsolateSystemId'] : null;
    String isolateName = (message.containsKey('to')) ? message['to'] : null;
    String replyTo = (message.containsKey('replyTo')) ? message['replyTo'] : null;
    String msg = (message['message']);

    var enqueueMessage = JSON.encode({'targetIsolateSystemId':targetSystem, 'isolateName':isolateName, 'action':Mqs.ENQUEUE, 'payload':{'message':msg, 'replyTo':replyTo}});


    print(enqueueMessage);
    //String a = JSON.encode(enqueueMessage).toString();
    //print(JSON.decode(a));

    socket.add(enqueueMessage);
  });
}

_onData(var message) {

}

_onError() {
  print("Error on Server, reconnect !");
}

_onDisconnect() {
  print("Disconnected, try re-establish the connection");
}
