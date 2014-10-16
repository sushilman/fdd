part of isoalteregistry.registry;

void startRestServer() {


  var routes = {
      "registry":{
          "systems": new HttpRestRoute({
              'GET': fooBar
          }), "addisolate": new HttpRestRoute({
              'POST': fooBat,
              'GET' : HttpRest.NO_CONTENT
          })
      }
  };
  HttpRest rest;

  rest = new HttpRest(routes);

  HttpServer.bind('127.0.0.1', 8000).then((server) {
    server.listen((HttpRequest request) {
      try {
        rest.resolve(request);
      }
      on RouteNotFoundException
      {
        request.response.close();
      }
    });
  });

}

fooBar() {

  return new HttpRestResponse().build(200, "FooBar !!!\n ${JSON.encode(getConnectedSystems())}");
}

fooBat() {
  return new HttpRestResponse().build(201, "called FooBat\n");
}

