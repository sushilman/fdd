import 'dart:isolate';
import 'dart:math';

import 'package:isolatesystem/worker/Worker.dart';
import 'AvailableSupplies.dart';

main(List<String> args, SendPort sendPort) {
  new Supplier(args, sendPort);
}

class Supplier extends Worker {
  Supplier(List<String> args, SendPort sendPort):super(args, sendPort);

  onReceive(message) {
    //prepare and respond to with requested item
    String responseMessage = "";
    switch(message['requestMessage']) {
      case AvailableSupplies.RANDOM_FRUIT:
        responseMessage = _randomFruit();
        break;
      case AvailableSupplies.RANDOM_NUMBER:
        responseMessage = _randomNumber();
        break;
      case AvailableSupplies.RANDOM_NAME:
        responseMessage = _randomName();
        break;
    }
    Map response = {
        'requestedAt': message['requestedAt'],
        'repliedAt': new DateTime.now().millisecondsSinceEpoch,
        'requestMessage': message['requestMessage'],
        'responseMessage': responseMessage};

    reply(response);
    done();
  }

  String _randomFruit() {
    int number = new Random().nextInt(5);
    return ["APPLE", "ORANGE", "KIWI", "PEAR", "GRAPES"][number];
  }

  String _randomNumber() {
    return new Random().nextInt(99999).toString();
  }

  String _randomName() {
    int number = new Random().nextInt(5);
    return ["Lorna", "Ambrose", "Domingo", "Kirsten", "Zachery"][number];
  }
}
