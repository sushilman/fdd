import 'dart:isolate';
import 'dart:convert';
import 'dart:async';
import 'dart:io' show sleep;
import 'dart:math' as Math;

import 'package:isolatesystem/worker/Worker.dart';
/**
 * A sample hello isolate
 */
main(List<String> args, SendPort sendPort) {
  //print ("Printer Isolate started...");
  HelloPrinter printerIsolate = new HelloPrinter(args, sendPort);
}

class HelloPrinter extends Worker {
  int counter = 0;

  HelloPrinter(List<String> args, SendPort sendPort) : super(args, sendPort);

  @override
  onReceive(message) {
    if(message is SendPort) {
      //use this to save sendports of spawned temporary isolates
    } else {
      outText(message);
    }
  }

  /**
   * Just an example of long running method
   * which might take varied amount of time to complete
   */
  outText(var message) {
    int rand = new Math.Random().nextInt(10);
    Duration duration = new Duration(seconds: rand);
    print("\n\n Processed by Worker ID: $id");
    print("=======================================================");
    String whiteSpace = "                                                           ";
    if(whiteSpace.length > message.length) {
      whiteSpace = whiteSpace.substring(message.length + 1);
    }
    String text = """
                                                               .---.
                                                              /  .  \\
                                                             |\\_/|   |
                                                             |   |  /|
  .----------------------------------------------------------------' |
 /  .-.                                                              |
|  /   \\                                                             |
| |\\_.  | $message $whiteSpace|
|\\|  | /|                                                            |
| `---' |  ***                                                       |
|       |                                                            |
|       |                                                           /
|       |----------------------------------------------------------'
\\       |
 \\     /
  `---'

    """;
    print(text);
    print("doing something for $rand seconds...\n\n");
    sleep(duration);
    //reply(message, replyTo:poolName);
    reply(message);
    //send("DONE !", replyTo:poolName);
    //done("DONE !");
    //done();
  }
}