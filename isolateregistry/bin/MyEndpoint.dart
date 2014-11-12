library isolateregistry.MyEndpoint;

import 'dart:io';
import 'dart:convert' show UTF8, JSON;
import 'Registry.dart';

class MyEndpoint {
  MyEndpoint() {
    final HOST = InternetAddress.ANY_IP_V4;
    final PORT = 8000;
    HttpServer.bind(HOST, PORT).then((_server) {
      _server.listen((HttpRequest request) {
        print("Request:${request.session.id}");
        addCorsHeaders(request.response);
        switch (request.method) {
          case 'GET':
            handleGetRequest(request);
            break;
          case 'POST':
            handlePostRequest(request);
            break;
          case 'OPTIONS':
            handleOptions(request);
            break;
          default:
            defaultHandler(request);
            break;
        }
      },
      onError: handleError);    // listen() failed.
    }).catchError(handleError);
  }

  handleGetRequest(HttpRequest request) {
    print("GET: ${request.uri.path}");
    if(request.uri.path == '/registry/system/list') {
      request.response.statusCode = HttpStatus.OK;
      request.response.headers.contentType = ContentType.JSON;
      List connectedNodes = registry.getConnectedNodes();
      request.response.write(JSON.encode(connectedNodes));
      request.response.close();
    } else if (request.uri.path.startsWith('/registry/system/')) {
      String bootstrapperId = request.uri.path.split('/').last;
      request.response.statusCode = HttpStatus.OK;
      request.response.headers.contentType = ContentType.JSON;
      registry.getNodeDetails(bootstrapperId, request);
    } else {
      defaultHandler(request);
    }
  }

  handlePostRequest(HttpRequest request) {
      if(request.uri.path == '/registry/deploy') {
        print("Deploying ${request.uri.path}");
        request.response.statusCode = HttpStatus.OK;
        UTF8.decodeStream(request).then((data) {
          try {
            Map isolateSystem = JSON.decode(data);
            registry.deployIsolate(isolateSystem);
          } on Exception {
            request.response.write("Body must be a json data");
            print("Bad Data");
          }
        });
      } else if(request.uri.path == '/registry/system/shutdown') {
        UTF8.decodeStream(request).then((data) {
          try {
            Map isolateSystem = JSON.decode(data);
            registry.shutdownIsolateSystemOnNode(isolateSystem);
          } on Exception {
            request.response.write("Body must be a json data: $data");
            print("Bad Data: $data");
          }
        });
      } else {
        defaultHandler(request);
      }
    request.response.close();
  }

  void addCorsHeaders(HttpResponse response) {
    response.headers.add("Access-Control-Allow-Origin", "*");
    response.headers.add("Access-Control-Allow-Methods", "POST, GET, OPTIONS");
    response.headers.add("Access-Control-Allow-Headers", "Origin, X-Requested-With, Content-Type, Accept");
  }

  void handleOptions(HttpRequest request) {
    HttpResponse response = request.response;
    print("${request.method}: ${request.uri.path}");
    response.statusCode = HttpStatus.NO_CONTENT;
    response.close();
  }

  void defaultHandler(HttpRequest request) {
    HttpResponse response = request.response;
    addCorsHeaders(response);
    response.statusCode = HttpStatus.NOT_FOUND;
    response.write("Not found: ${request.method}, ${request.uri.path}");
    response.close();
  }

  handleError(var message) {
    print ("Error $message");
  }
}

main() {
  new MyEndpoint();
}
