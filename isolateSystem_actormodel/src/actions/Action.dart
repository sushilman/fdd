library isolatesystem.actions.Action;

class Action {
  static const SPAWN = "SPAWN";
  static const NONE = "NONE";
  static const PULL_MESSAGE = "PULL_MESSAGE";
  // when tasks are completed? find better term
  static const DONE = "DONE";

  // When isolate spawning has been completed and now it is ready to accept actions
  static const READY = "READY";
}