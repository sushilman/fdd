import 'dart:isolate';
import 'dart:async';
import '../messages/Messages.dart';
import '../IsolateSystem.dart';

/**
 * Will be spawned by Activator?
 */

/**
 * Controller
 * needs many sendports -> list of all the routers it has spawned
 *
 * Should keep track of free isolates (with the help of router)
 * and send pull request to IsolateSystem
 */
main(List<String> args, SendPort sendPort) {
  Controller controller = new Controller(sendPort);
  controller.main(args);
}

class Controller {
  ReceivePort receivePort;
  SendPort sendPortOfIsolateSystem;
  int workersCount;
  /**
   * Send ports of all routers this controller has spawned
   */
  List<SendPort> routerSendPorts = new List<SendPort>();

  //TODO: check proposal -> should be single router per isolate system
  Map<Uri, Isolate> routerIsolates = new Map<Uri, Isolate>();

  Controller(this.sendPortOfIsolateSystem);

  main(List<String> args) {
    receivePort = new ReceivePort();
    SendPort self = receivePort.sendPort;
    sendPortOfIsolateSystem.send(receivePort.sendPort);

    Uri routerUri = Uri.parse(args[0]);
    Uri workerUri = Uri.parse(args[1]);
    workersCount = args[2];

    receivePort.listen((message) {
      _onReceive(message, receivePort);
    });

    spawnRouters(receivePort, routerUri, workerUri, workersCount);
  }

  _onReceive(var message, ReceivePort receivePort) {
    print("Controller: $message");
    if(message is SendPort) {
      routerSendPorts.add(message);
    } else if (message is Event) {
      switch (message.action) {
        case Action.SPAWN:
          // Do nothing
        break;
        case Action.READY:
        case Action.DONE:
          for(int i = 0; i < workersCount; i++) {
            sendPortOfIsolateSystem.send(Messages.createEvent(Action.PULL_MESSAGE, null));
          }
        break;
        default:
        break;
      }
    } else if (message is String) {
      // For now, just delegate message to first router
      routerSendPorts[0].send(message);
    }
  }

  spawnRouters(ReceivePort receivePort, Uri routerUri, Uri workerUri, int workersCount) {
    //Uri routerUri = Uri.parse("../${message.message["router"]}");
    //int num = int.parse(message.message["count"]);
    //print ("Pass message to router to spawn $num isolates with routing $routerUri");
    //sendPort.send(Messages.createEvent(Action.NONE, "Delegated message to create $num isolates with routing $routerUri"));

    Isolate.spawnUri(routerUri, [workerUri, workersCount], receivePort.sendPort).then((isolate) {
      routerIsolates[routerUri] = isolate;
    });
  }
}