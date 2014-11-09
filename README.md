# FDD
===

Framework for Distributed Dart

 - Dart Dart Everywhere (DDE) - https://imgflip.com/i/d0wrw
 - Ballistic Dart (BD)
 - Multi Dart (MD)

Quick Getting Started Guide:

 1. Check out the repo
 2. Install and run rabbitmq-server
 3. run "pub get" in all of the top level directories (each directory is a dart project with its own pubspec.yaml)
 4. Start up messageQueuingSystem/bin/Mqs.dart (dart Mqs.dart)

To tryout ping-pong without using Registry, IsolateDeployer & Bootstrapper --
 * Start up helloSystem/bin/PingPongSystem.dart (dart PingPongSystem.dart)

To Tryout HelloPrinter with Bootstrapper --
* Run isolateregistry/Registry.dart
* Run activator/Activator.dart
* Send a GET request using POSTMAN or any rest client to http://localhost:8000/registry/systems
* POST request to deploy ping isolate

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

* Run messageQueueingSystem/bin/EnqueueTest for few seconds and stop it by breaking (Ctrl+C).
* The printer isolate should start printing the enqueued messages in terminal
