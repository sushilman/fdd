library isolateregistry.Endpoint;
import 'package:redstone/server.dart' as app;
import 'package:di/di.dart';
import 'Registry.dart';

@app.Group('/registry')
class Endpoint {

  Endpoint() {
    app.addModule(new Module()..bind(Endpoint));
    app.setupConsoleLog();
    app.start(address:"0.0.0.0", port:8000);
  }

  @app.Route("/systems", methods: const[app.GET])
  list() {
    return registry.getConnectedSystems();
  }

  @app.Route("/deploy", methods: const[app.POST])
  addIsolate(@app.Body(app.JSON) Map isolateSystem) {
    registry.deployIsolate(isolateSystem);
  }


}