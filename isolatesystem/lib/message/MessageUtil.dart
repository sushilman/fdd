library isolatesystem.message.MessageUtil;

class MessageUtil {
  static create(String senderType, String id, String action, var payload) {
    return {'senderType' : senderType, 'id' : id, 'action': action, 'payload' : payload};
  }

  static getSenderType(Map message) {
    try {
      return message['senderType'];
    } catch (e) {
      return null;
    }
  }

  static setSenderType(String senderType, Map message) {
    try {
      message['senderType'] =  senderType;
      return message;
    } catch (e) {
      return null;
    }
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
