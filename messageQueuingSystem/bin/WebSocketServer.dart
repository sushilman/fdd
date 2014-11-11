import 'dart:io';

class WebSocketServer {

  WebSocketServer(int port, String path, void onConnect(WebSocket socket, String isolateSystemName, String isolateSystemUniqueId), void onData(WebSocket socket, String systemName, String systemUniqueId, var message), void onDisconnect(WebSocket socket, String systemName, String systemUniqueId)) {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
      print("HttpServer listening for websocket connections...");
      server.serverHeader = "MessageQueuingSystemServer";
      server.listen((HttpRequest request) {
        print('listening on $path \n request on ' + request.uri.toString());
        if (request.uri.path.startsWith(path)) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then((socket) {
              String subPath = request.uri.path.substring(path.length + 1);
              //print('WebSocketServer: System and Id = $subPath');
              handleWebSocket(subPath, socket, onConnect, onData, onDisconnect);
            });
          } else {
            serveRequest(request);
          }
        }
      });
    });
  }

  handleWebSocket(String subPath, WebSocket socket,
                  void onConnect(WebSocket socket, String isolateSystemName, String isolateSystemUniqueId),
                  void onData(WebSocket socket, String isolateSystemName, String isolateSystemUniqueId, var message),
                  void onDisconnect(WebSocket socket, String isolateSystemName, String isolateSystemUniqueId)) {
    print('Client connected!');

    List<String> pathParts = subPath.split('/');
    String isolateSystemName = pathParts[0];
    String isolateSystemUniqueId = pathParts[1];

    onConnect(socket, isolateSystemName, isolateSystemUniqueId);
    socket.listen((String s) {
      onData(socket, isolateSystemName, isolateSystemUniqueId, s);
    }, onDone: () {
      print('Client disconnected');
      onDisconnect(socket, isolateSystemName, isolateSystemUniqueId);
    });
  }

  serveRequest(HttpRequest request) {
    request.response.statusCode = HttpStatus.FORBIDDEN;
    request.response.reasonPhrase = "WebSocket connections only";
    request.response.close();
  }
}