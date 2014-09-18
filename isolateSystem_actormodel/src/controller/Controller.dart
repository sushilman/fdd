import 'dart:isolate';
import 'dart:async';
import '../messages/Messages.dart';
import '../IsolateSystem.dart';

/**
 * Controller
 * needs many sendports -> list of all the routers it has spawned
 *
 * Should keep track of free isolates (with the help of router)
 * and send pull request to IsolateSystem
 */
main(List<String> args, SendPort sendPort) {
  Controller controller = new Controller(args, sendPort);
}

class Controller {
  ReceivePort receivePort;
  SendPort sendPortOfIsolateSystem;
  SendPort self;
  int workersCount;
  /**
   * Send port the router this controller has spawned
   */
  SendPort routerSendPort;

  //TODO: check proposal -> should be single router per isolate system
  Uri routerUri;
  Isolate routerIsolate;

  Controller(List<String> args, this.sendPortOfIsolateSystem) {
    receivePort = new ReceivePort();
    self = receivePort.sendPort;
    sendPortOfIsolateSystem.send(receivePort.sendPort);

    Uri routerUri = Uri.parse(args[0]);
    Uri workerUri = Uri.parse(args[1]);
    workersCount = args[2];

    receivePort.listen((message) {
      _onReceive(message, receivePort);
    });

    spawnRouter(receivePort, routerUri, workerUri, workersCount);
  }

  _onReceive(var message, ReceivePort receivePort) {
    print("Controller: $message");
    if(message is SendPort) {
      routerSendPort = message;
    } else if (message is Event) {
      switch (message.action) {
        case Action.SPAWN:
          // Do nothing
        break;
        case Action.READY:
          for(int i = 0; i < workersCount; i++) {
            sendPortOfIsolateSystem.send(Messages.createEvent(Action.PULL_MESSAGE, null));
          }
        break;
        case Action.DONE:
          sendPortOfIsolateSystem.send(Messages.createEvent(Action.PULL_MESSAGE, null));
        break;
        default:
        break;
      }
    } else if (message is String) {
      // For now, just delegate message to the router
      routerSendPort.send(message);
    }
  }

  spawnRouter(ReceivePort receivePort, Uri routerUri, Uri workerUri, int workersCount) {
    Isolate.spawnUri(routerUri, [workerUri, workersCount], receivePort.sendPort).then((isolate) {
      routerUri = routerUri;
      routerIsolate = isolate;
    });
  }
}