import "package:stomp/stomp.dart";
import "package:stomp/vm.dart" show connect;
import "Mqs.dart";

class Test {
  Test() {
  }
}

void main() {
//  connect("127.0.0.1", port:61613, login:"guest", passcode:"guest").then((StompClient client) {
//    client.subscribeString("id1", "/queue/test",
//        (Map<String, String> headers, String message) {
//      print ("Receive $message $headers");
//    });
//
//    Map<String, String> sendHeaders = new Map();
//    sendHeaders["reply-to"] = "/temp-queue/foo";
//    client.sendString("/queue/test", "Hi, Stomp");
//  });

  Mqs mqs = new Mqs(host:"127.0.0.1", port:61613);

  Map<String, String> headers= new Map();
  headers["reply-to"] = "/temp-queue/foo";
  //while(!mqs.enqueueMessage("/queue/test", "Hi, Stomp", headers: headers));


}
