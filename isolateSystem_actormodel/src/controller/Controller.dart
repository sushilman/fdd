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
 */
main(List<String> args, SendPort sendPort) {
  ReceivePort receivePort = new ReceivePort();
  sendPort.send(receivePort.sendPort);

  Controller controller = new Controller();

  Uri routerUri = Uri.parse(args[0]);
  Uri workerUri = Uri.parse(args[1]);
  int workersCount = args[2];

  receivePort.listen((message) {
    controller._onReceive(message, sendPort, receivePort);
  });

  controller.spawnRouters(receivePort, routerUri, workerUri, workersCount);
}

class Controller {
  /**
   * Send ports of all routers this controller has spawned
   */
  List<SendPort> routerSendPorts = new List<SendPort>();
  Map<Uri, Isolate> routerIsolates = new Map<Uri, Isolate>();

  _onReceive(message, sendPort, receivePort) {
    //print("Message: $message");
    if(message is SendPort) {
      routerSendPorts.add(message);
    } else if (message is Event) {
      switch (message.action) {
        case Action.SPAWN:
          // Do nothing
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