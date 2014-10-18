import 'dart:io';
import 'dart:convert' show UTF8, JSON;

class MyEndpoint {
  MyEndpoint() {
    final HOST = InternetAddress.LOOPBACK_IP_V4;
    final PORT = 8000;

    HttpServer.bind(HOST, PORT).then((_server) {
      _server.listen((HttpRequest request) {
        switch (request.method) {
          case 'GET':
            handleGetRequest(request);
            break;
          case 'POST':
            handlePostRequest(request);
            break;
        }
      },
      onError: handleError);    // listen() failed.
    }).catchError(handleError);
  }

  handleGetRequest(HttpRequest request) {
    if(request.uri.path == '/registry/systems') {
      request.response.statusCode = HttpStatus.OK;
      request.response.write("Nice");
      request.response.close();
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
            Map receivedData = JSON.decode(data);
            request.response.write('$receivedData');
            print('ECHO written $receivedData');
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


  handleError(var message) {
    print ("Error $message");
  }
}

main() {
  new MyEndpoint();
}
