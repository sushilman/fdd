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
    //return [senderType, id, action, payload];
    return {'senderType' : senderType, 'id' : id, 'action': action, 'payload' : payload};
  }

  static getSenderType(Map message) {
    try {
      return message['senderType'];
    } catch (e) {
      return null;
    }
//    try {
//      return message[0];
//    } catch (e) {
//      return null;
//    }
  }

  static getId(Map message) {
    try {
      return message['id'];
    } catch (e) {
      return null;
    }
  }

  static getAction(Map message) {
    try {
      return message['action'];
    } catch (e) {
      return null;
    }
  }

  static getPayload(Map message) {
    try {
      return message['payload'];
    } catch (e) {
      return null;
    }
  }

  static isValidMessage(var message) {
    return (message is Map);
  }
}
