import 'dart:io';

class WebSocketServer {

  WebSocketServer(int port, String path) {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
      print("HttpServer listening...");
      server.serverHeader = "EchoServer";
      server.listen((HttpRequest request) {
        print('listening on $path \n request on ' + request.uri.toString());
        if(request.uri.path == path) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then(handleWebSocket);
          } else {
            print("Regular ${request.method} request for: ${request.uri.path}");
            serveRequest(request);
          }
        }
      });
    });
  }

  void handleWebSocket(WebSocket socket){
    print('Client connected!');
    socket.listen((String s) {
      print('Client sent: $s');
      socket.add('echo: $s');
    },
    onDone: () {
      print('Client disconnected');
    });
  }

  void serveRequest(HttpRequest request){
    request.response.statusCode = HttpStatus.FORBIDDEN;
    request.response.reasonPhrase = "WebSocket connections only";
    request.response.close();
  }
}