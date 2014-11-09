library account;
import 'dart:isolate';
import 'dart:convert';

import 'package:isolatesystem/worker/Worker.dart';

import 'accountIsolate.dart';

main(List<String> args, SendPort sendPort) {
  new Account(args, sendPort);
}

class Account extends Worker {
  static const String SAVINGS_ACCOUNT = "account.savings";
  static const String CHECKING_ACCOUNT = "account.checking";

  static const String CREATE = "action.create";
  static const String CHECK_BALANCE = "action.checkBalance";
  static const String WITHDRAW = "action.withdraw";
  static const String DEPOSIT = "action.deposit";

  static const String CREATED = "created";
  static const String ALREADY_CREATED = "alreadCreated";

  Map<String, SendPort> sendPorts;
  ReceivePort receivePort;
  List messageBuffer;

  Account(List<String> args, SendPort sendPort) : super(args, sendPort) {
    sendPorts = {};
    messageBuffer = [];
    receivePort = new ReceivePort();
    receivePort.listen(onReceive);
  }

  /**
   * Expects message in the format of {'id':.., 'action':.., 'value':..}
   *
   *  value is optional depending upto type of action
   */
  onReceive(message) {
    if(message is List && message[1] is SendPort) {
      print("Setting ${message[0]} to ${message[1]}");
      sendPorts[message[0]] = message[1];
      _clearBuffer();
      done();
    }  else {
      if(message is String) {
        try {
          message = JSON.decode(message);
        } catch(e) {}
      }
      String senderType;

      if(message is Map) {
        if(message.containsKey('senderType')) {
          senderType = message['senderType'];
        }

        if(senderType == "sender.accountIsolate") {
          _handleMessageFromAccountIsolate(message);
        } else {
          _handleMessagesFromUser(message);
        }
      }
    }
  }

  void _handleMessageFromAccountIsolate(var message) {
    reply(message['message']);
    done();
  }

  void _handleMessagesFromUser(var message) {
    switch (message['action']) {
      case CREATE:
        if (sendPorts.containsKey(message['id'])) {
          if (sendPorts[message['id']] != null) {
            sendPorts[message['id']].send(message);
          } else {
            messageBuffer.add(message);
          }
        } else {
          spawnIsolate(message);
        }
        break;
      default:
        if (sendPorts.containsKey(message['id']) && sendPorts[message['id']] != null) {
          sendPorts[message['id']].send(message);
        } else {
          messageBuffer.add(message);
        }
    }
  }

  void spawnIsolate(var message) {
    sendPorts[message['id']] = null;
    Isolate.spawn(accountIsolate, {'id':message['id'], 'sendPort':receivePort.sendPort});
  }

  _clearBuffer() {
    while (messageBuffer.isNotEmpty) {
      workerReceivePort.sendPort.send(messageBuffer.removeAt(0));
    }
  }
}
