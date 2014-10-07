library isolatesystem.actions.Action;

class Action {
  static const String ADD = "action.add";
  static const String SPAWN = "action.spawn";
  static const String NONE = "action.none";
  static const String PULL_MESSAGE = "action.pull";

  // when tasks are completed by an isolate.
  static const String DONE = "action.done";

  // When isolate spawning has been completed and now it is ready to accept action
  static const String CREATED = "action.created";

  static const String DOWNLOAD = "action.download";
  static const String ERROR = "action.error";
  // message sent to an isolate to stop the isolate
  static const String KILL = "action.kill";
  static const String KILL_ALL = "action.kill_all";

  // message sent to an isolate to restart the isolate
  static const String RESTART = "action.restart";
  static const String RESTART_ALL = "action.restart_all";

  // message replied by isolate that it is going to end (close it's receivePort)
  static const String KILLED = "action.killed";
  static const String RESTARTING = "action.restarting";
}