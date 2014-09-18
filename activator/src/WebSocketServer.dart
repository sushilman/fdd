import 'dart:io';
import 'dart:async';

class WebSocketServer {

  WebSocketServer(int port, String path, void onData(var message)) {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
      print("HttpServer listening...");
      server.serverHeader = "EchoServer";
      server.listen((HttpRequest request) {
        print('listening on $path \n request on ' + request.uri.toString());
        if(request.uri.path == path) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then((socket) {
              handleWebSocket(socket, onData);
            });
          } else {
            print("Regular ${request.method} request for: ${request.uri.path}");
            serveRequest(request);
          }
        }
      });
    });
  }

  handleWebSocket(WebSocket socket, void onData(var message)) {
    print('Client connected!');
    socket.listen((String s) {
      onData(s);
      print('Client sent: $s');
      socket.add('echo: $s');
    },
    onDone: () {
      print('Client disconnected');
    });
  }

  serveRequest(HttpRequest request){
    request.response.statusCode = HttpStatus.FORBIDDEN;
    request.response.reasonPhrase = "WebSocket connections only";
    request.response.close();
  }
}