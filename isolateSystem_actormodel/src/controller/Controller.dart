import 'dart:isolate';
import 'dart:async';
import '../messages/Messages.dart';

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

  receivePort.listen((message) {
    controller._onReceive(message, sendPort, receivePort);
  });
}

class Controller {
  /**
   * Send ports of all routers this controller has spawned
   */
  List<SendPort> routerSendPorts = new List<SendPort>();
  Map<Uri, Isolate> routerIsolates = new Map<Uri, Isolate>();

  _onReceive(message, sendPort, receivePort) {
    print("Message: $message");
    if (message is Event) {
      switch (message.action) {
        case Action.SPAWN:
          Uri routerUri = Uri.parse("../${message.message["router"]}");
          int num = int.parse(message.message["count"]);
          print ("Pass message to router to spawn isolates $num with routing $routerUri");
          sendPort.send(Messages.createEvent(Action.NONE, "Delegated message to create $num isolates with routing $routerUri"));
          Isolate.spawnUri(routerUri, null, receivePort.sendPort).then((isolate){
            routerIsolates.putIfAbsent(routerUri, isolate);
          });
          break;
        default:
          print ("No action");
        break;
      }
    } else if(message is SendPort) {
      routerSendPorts.add(message);
    }
  }
}