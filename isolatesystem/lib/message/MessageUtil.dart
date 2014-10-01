library isolatesystem.message.MessageUtil;

/*
 * Message Structure:
 * [0] -> Message From <Type> - type: isolate system, controller, router, worker
 * [1] -> ID
 * [2] -> Action
 * [3] -> message -> can be String or List
 */

class MessageUtil {
  static create(String senderType, String id, String action, var payload) {
    return [senderType, id, action, payload];
  }

  // Just an idea for performance improvement?
  static update(String senderType, String id, var message) {
    message[0] = senderType;
    message[1] = id;
    return message;
  }

  static getSenderType(List<String> message) {
    return message[0];
  }

  static getId(List<String> message) {
    return message[1];
  }

  static getAction(List<String> message) {
    return message[2];
  }

  static getPayload(List<String> message) {
    return message[3];
  }

  static isValidMessage(var message) {
    return (message is List);
  }
}
