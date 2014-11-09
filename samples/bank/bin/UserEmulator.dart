library account.useremulator;
import 'dart:isolate';
import 'dart:convert';
import 'dart:math';
import 'package:isolatesystem/worker/Worker.dart';

import 'account.dart';
import 'accountInfo.dart';

main(List<String> args, SendPort sendPort) {
  new UserEmulator(args, sendPort);
}
/**
 * Creates few accounts and performs random operations on random accounts
 */
class UserEmulator extends Worker {
  static const NUMBER_OF_TRANSACTIONS = 1000;

  String accountWorkerAddress = "bank/account";
  List accountIds = ["A001", "A002", "A003"];
  List names = ["John", "Chan", "Bane"];

  UserEmulator(List<String> args, SendPort sendPort):super(args, sendPort) {
    for(int i = 0; i < accountIds.length; i++) {
      AccountInfo accountInfo = new AccountInfo(accountIds[i], names[i], Account.CHECKING_ACCOUNT, 1000);
      Map createMessage = {'action':Account.CREATE, 'id':accountIds[i], 'accountInfo':JSON.encode(accountInfo)};
      send(createMessage, accountWorkerAddress);
    }
  }

  onReceive(message) {
    if(message == Account.CREATED || message == Account.ALREADY_CREATED) {
      Random random = new Random();
      for(int i = 0; i < NUMBER_OF_TRANSACTIONS; i++) {
        bool randomChoice = random.nextBool();
        int randomInt = random.nextInt(accountIds.length);
        String accountId = accountIds[randomInt];

        Map queryMessage = {'action':Account.CHECK_BALANCE, 'id':accountId};
        Map depositMessage = {'action':Account.DEPOSIT, 'id':accountId, 'value':1000};
        Map withdrawMessage = {'action':Account.WITHDRAW, 'id':accountId, 'value':4000};

        if(randomChoice) {
          send(depositMessage, accountWorkerAddress);
        } else {
          send(withdrawMessage, accountWorkerAddress);
        }
      }
    } else {
      String output = """
        Account Holder: ${message['accountHolder']}
        Old Balance: ${message['oldBalance']}
        Transaction Details: ${message['transactionDetails']}
        New Balance: ${message['newBalance']}
      """;
      if(message['errorMessage'] != null) {
        output += "  Error Message: ${message['errorMessage']}\n";
      }
      print(output);
    }
    done();
  }
}
