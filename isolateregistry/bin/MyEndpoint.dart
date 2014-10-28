library isolateregistry.MyEndpoint;

import 'dart:io';
import 'dart:convert' show UTF8, JSON;
import 'Registry.dart';

class MyEndpoint {
  MyEndpoint() {
    final HOST = InternetAddress.LOOPBACK_IP_V4;
    final PORT = 8000;

    HttpServer.bind(HOST, PORT).then((_server) {
      _server.listen((HttpRequest request) {
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
    if(request.uri.path == '/registry/systems/list') {
      request.response.statusCode = HttpStatus.OK;
      request.response.headers.contentType = ContentType.JSON;
      List connectedNodes = registry.getConnectedNodes();
      request.response.write(JSON.encode(connectedNodes));
      request.response.close();
    } else if (request.uri.path.startsWith('/registry/systems/')) {
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
      print("${request.headers.contentType.value}\n${request.headers}");
      if (request.headers.contentType.value.toLowerCase() == ContentType.JSON.value.toLowerCase()) {
        request.response.statusCode = HttpStatus.OK;
        UTF8.decodeStream(request).then((data) {
          print('$data');
          try {
            Map isolateSystem = JSON.decode(data);
            registry.deployIsolate(isolateSystem);
          } on Exception {

            request.response.statusCode = HttpStatus.BAD_REQUEST;
            request.response.write("body must be json data");
            print("bad data");
          }
        });
      } else {
        request.response.statusCode = HttpStatus.BAD_REQUEST;
        request.response.write("Content-Type must be application/json");
        print ("bad content type or no content type");
      }
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
