library isolatesystem.actions.Action;

class Action {
  static const String SPAWN = "SPAWN";
  static const String NONE = "NONE";
  static const String PULL_MESSAGE = "PULL_MESSAGE";
  // when tasks are completed? find better term
  static const String DONE = "DONE";

  // When isolate spawning has been completed and now it is ready to accept action
  static const String READY = "READY";

  static const String ERROR = "ERROR";
  static const String KILLED = "KILLED";
}