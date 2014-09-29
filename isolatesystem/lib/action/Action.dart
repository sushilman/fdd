library isolatesystem.actions.Action;

class Action {
  static const String SPAWN = "SPAWN";
  static const String NONE = "NONE";
  static const String PULL_MESSAGE = "PULL_MESSAGE";

  // when tasks are completed by an isolate.
  static const String DONE = "DONE";

  // When isolate spawning has been completed and now it is ready to accept action
  static const String READY = "READY";

  static const String DOWNLOAD = "DOWNLOAD";
  static const String ERROR = "ERROR";
  // message sent to an isolate to stop the isolate
  static const String KILL = "KILL";
  static const String KILL_ALL = "KILL_ALL";

  // message sent to an isolate to restart the isolate
  static const String RESTART = "RESTART";
  static const String RESTART_ALL = "RESTART_ALL";

  // message replied by isolate that it is going to end (close it's receivePort)
  static const String KILLED = "KILLED";
  static const String RESTARTING = "RESTARTING";
}