# FDD

##Framework for Distributed Dart

 - Dart Dart Everywhere (DDE) - https://imgflip.com/i/d0wrw
 - Ballistic Dart (BD)
 - Multi Dart (MD)

##Quick Getting Started Guide:
1. Checkout `fdd` repository
2. Run `pub get` in all of the projects:
  * activator
  * isolateregistry
  * isoaltesystem
  * messageQueuingSystem
  * registryWebclient
  * sample projects inside 'samples'
3. Install rabbitmq
4. [Enable STOMP plugin in rabbitmq](https://www.rabbitmq.com/stomp.html): `rabbitmq-plugins enable rabbitmq_stomp`
5. Start `rabbitmq-server`
6. Start Message Queuing System:
  * `cd messageQueuingSystem/bin`
  * `dart Mqs.dart`
7. Start Isolate Registry:
  * `cd isolateregistry/bin`
  * `dart Registry.dart`
8. For Web-based FDD manager:
  * If you have Dartium, simply open `registryWebclient/web/index.html`
  * else, `cd registryWebclient`
    * `pub serve` or `pub serve 0.0.0.0`
    * Open any browser: http://localhost:8080
  * Enter hostname and management port of registry to connect and manage.
9. Now, Start activator with websocket address of registry as argument
  * `cd activator/bin`
  * `dart SystemBootstrapper.dart ws://locahost:42044/registry`
10. Reload the management interface, the connected node will be shown with ip
11. Select the node and click `+` icon to deploy new isolates in that node
12. Fill the form to deploy
  * appropriate isolateSystem name and isolateName as used in the code to deploy
  * enter absolute path to file or URI of the source file
  * choose one of the listed routers or provide absolute uri to own implementation of router
  * the deployment path can be separated by comma for multiple locations and multiple instances of an isolate worker
  * finally, enter the websocket path to MessageQueuingSystem to connect to

The Web interface is simply a frontend to REST API exposed by registry management.
A simple sample request looks like this:
<pre>
{
 "bootstrapperId" : "use id that you get from GET request",
 "action": "action.addIsolate",
 "messageQueuingSystemServer": "ws://localhost:42043/mqs",
 "systemId" : "isolateSystem",
 "isolateName" : "helloPrinter",
 "uri" : "absolute/path/to/helloSystem/HelloPrinter.dart",
 "workerPaths" : "[localhost, localhost]",
 "routerType" : "random",
 "hotDeployment" : false,
 "args" : null
}
</pre>
