import 'dart:io';
import 'dart:async';

class WebSocketServer {

  WebSocket webSocket;

  WebSocketServer(int port, String path, void onData(var message)) {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
      print("HttpServer listening...");
      server.serverHeader = "EchoServer";
      server.listen((HttpRequest request) {
        print('listening on $path \n request on ' + request.uri.toString());
        if(request.uri.path == path) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then((socket) {
              webSocket = socket;
              handleWebSocket(onData);
            });
          } else {
            print("Regular ${request.method} request for: ${request.uri.path}");
            serveRequest(request);
          }
        }
      });
    });
  }

  handleWebSocket(void onData(var message)) {
    print('Client connected!');
    webSocket.listen((String s) {
      onData(s);
      print('Client sent: $s');
      webSocket.add('echo: $s');
    },
    onDone: () {
      print('Client disconnected');
    });
  }

  send(String message) {
    webSocket.add(message);
  }

  serveRequest(HttpRequest request){
    request.response.statusCode = HttpStatus.FORBIDDEN;
    request.response.reasonPhrase = "WebSocket connections only";
    request.response.close();
  }
}