import 'dart:io';

class WebSocketServer {

  WebSocketServer(int port, String path, void onConnect(WebSocket socket, String subPath), void onData(WebSocket socket, var message), void onDisconnect(WebSocket socket)) {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
      print("HttpServer listening for websocket connections...");
      server.serverHeader = "MessageQueuingSystemServer";
      server.listen((HttpRequest request) {
        print('listening on $path \n request on ' + request.uri.toString());
        if (request.uri.path.startsWith(path)) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then((socket) {
              String subPath = request.uri.path.substring(path.length + 1);
              print('WebSocketServer: SystemId = $subPath');
              handleWebSocket(subPath, socket, onConnect, onData, onDisconnect);
            });
          } else {
            serveRequest(request);
          }
        }
      });
    });
  }

  handleWebSocket(String subPath, WebSocket socket, void onConnect(WebSocket socket, String path), void onData(WebSocket socket, var message), void onDisconnect(WebSocket socket)) {
    print('Client connected!');
    onConnect(socket, subPath);
    socket.listen((String s) {
      onData(socket, s);
    }, onDone: () {
      print('Client disconnected');
      onDisconnect(socket);
    });
  }

  serveRequest(HttpRequest request) {
    request.response.statusCode = HttpStatus.FORBIDDEN;
    request.response.reasonPhrase = "WebSocket connections only";
    request.response.close();
  }
}