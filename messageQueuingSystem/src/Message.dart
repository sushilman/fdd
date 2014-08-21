import 'dart:io';
import 'dart:convert' show JSON;

class Message {
  String topic;
  String message;
  Map<String,String> headers;

  Message(String topic, String message, Map<String, String> headers) {
    this.topic = topic;
    this.message = message;
    this.headers = headers;
  }

  fromJson(String json) {
    Object jsonObject = JSON.decode(json);
  }
}
