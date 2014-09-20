library activator.messages.Messages;
import 'dart:convert';

class Messages {
  static Event createEvent(Action action, var message) {
    return new Event(action, message);
  }
}

class Action {
  static const SPAWN = "SPAWN";
  static const NONE = "NONE";
  static const PULL_MESSAGE = "PULL_MESSAGE";
  // when tasks are completed? find better term
  static const DONE = "DONE";

  // When isolate spawning has been completed and now it is ready to accept messages
  static const READY = "READY";
}

class Event {
  Action _action;
  var _message;

  Event(this._action, this._message);

  get message => _message;
  set message(var value) => _message = value;

  Action get action => _action;
  set action(Action value) => _action = value;

  Map toJson() {
    Map map = new Map();
    map["action"] = action;
    map["message"] = message;
    return map;
  }
}