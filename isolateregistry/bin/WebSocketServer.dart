library isoalateregistry.WebSocketServer;

import 'dart:io';

class WebSocketServer {

  WebSocketServer(int port, String path, void onConnect(WebSocket socket, String remoteIP, String remotePort), void onData(WebSocket socket, var message), void onDisconnect(WebSocket socket)) {
    HttpServer.bind(InternetAddress.ANY_IP_V4, port).then((HttpServer server) {
      print("HttpServer listening for websocket connections...");
      server.serverHeader = "RegistryServer";
      server.listen((HttpRequest request) {
        String remoteIP = request.connectionInfo.remoteAddress.address;
        String remotePort = request.connectionInfo.remotePort.toString();

        print('Listening on $path \n request on ' + request.uri.toString() + ' by: ' + remoteIP + " on port " + remotePort);
        if (request.uri.path == path) {
          if (WebSocketTransformer.isUpgradeRequest(request)) {
            WebSocketTransformer.upgrade(request).then((socket) {
              handleWebSocket(socket, remoteIP, remotePort, onConnect, onData, onDisconnect);
            });
          } else {
            serveRequest(request);
          }
        }
      });
    });
  }

  handleWebSocket(WebSocket socket, String remoteIP, String remotePort,
                  void onConnect(WebSocket socket, String remoteIP, String remotePort),
                  void onData(WebSocket socket, var message),
                  void onDisconnect(WebSocket socket)) {
    print('Client connected!');
    onConnect(socket, remoteIP, remotePort);
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