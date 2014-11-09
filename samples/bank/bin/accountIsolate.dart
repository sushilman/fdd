library bank.accountIsolate;

import 'dart:isolate';
import 'dart:convert';

import 'accountInfo.dart';
import 'account.dart';


accountIsolate(Map args) {
  new AccountIsolate(args);
}

/*
 * Spawned per account
 */
class AccountIsolate {
  ReceivePort receivePort;
  SendPort sendPort;
  AccountInfo account;

  AccountIsolate(Map args) {
    receivePort = new ReceivePort();
    this.sendPort = args['sendPort'];
    sendPort.send([args['id'], receivePort.sendPort]);
    receivePort.listen(_onReceive);
  }

  _onReceive(var message) {
    String operation = "";
    if(account != null) {
      operation += "${account.id} => OldBalance = ${account.balance.toString()}";
    }
    operation += ", ${message['action']}, ${message['value']}: ";

    switch(message['action']) {
      case Account.CREATE:
        if(account == null) {
          account = new AccountInfo.fromMap(JSON.decode(message['accountInfo']));
          _sendToParentIsolate(Account.CREATED);
        } else {
          _sendToParentIsolate(Account.ALREADY_CREATED);
        }
        break;
      case Account.CHECK_BALANCE:
        _sendToParentIsolate(_createResponseMessage(account.accountHolder, account.balance, message['action'], account.balance));
        break;
      case Account.DEPOSIT:
        int oldBalance = account.balance;
        account.balance += message['value'];
        _sendToParentIsolate(_createResponseMessage(account.accountHolder, oldBalance, message['action'] + " " + message['value'].toString(), account.balance));
        break;
      case Account.WITHDRAW:
        int oldBalance = account.balance;
        if(account.balance >= message['value']) {
          account.balance -= message['value'];
          _sendToParentIsolate(_createResponseMessage(account.accountHolder, oldBalance, message['action'] + " " + message['value'].toString(), account.balance));
        } else {
          _sendToParentIsolate(_createResponseMessage(account.accountHolder, oldBalance, message['action']+ " " + message['value'].toString(), account.balance, errorMsg:"Insufficient Balance"));
        }
        break;
    }
  }

  Map _createResponseMessage(String accountHolder, int oldBalance, String transactionDetails, int newBalance, {String errorMsg}) {
    return {'accountHolder':accountHolder, 'oldBalance': oldBalance, 'transactionDetails': transactionDetails, 'newBalance':newBalance, 'errorMessage':errorMsg};
  }

  _sendToParentIsolate(var message) {
    sendPort.send(JSON.encode({'senderType':'sender.accountIsolate', 'message':message}));
  }

}