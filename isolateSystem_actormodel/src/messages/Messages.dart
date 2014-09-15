library isolatesystem.messages.Messages;

class Messages {
  static Event createEvent(Action action, var message) {
    return new Event(action, message);
  }
}

class Action {
  static const SPAWN = "SPAWN";
  static const NONE = "NONE";
}

class Event {
  Action _action;
  var _message;

  Event(this._action, this._message);

  get message => _message;
  set message(var value) => _message = value;

  Action get action => _action;
  set action(Action value) => _action = value;

}