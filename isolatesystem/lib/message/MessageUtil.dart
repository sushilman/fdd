library isolatesystem.message.MessageUtil;

class MessageUtil {
  static create(String senderType, String id, String action, var payload) {
    return {'senderType' : senderType, 'id' : id, 'action': action, 'payload' : payload};
  }

  static getSenderType(Map message) {
    try {
      if(message is List) {
        return message[0];
      }
      return message['senderType'];
    } catch (e) {
      return null;
    }
  }

  static setSenderType(String senderType, Map message) {
    try {
      if(message is List) {
        message[0] =  senderType;
      } else {
        message['senderType'] =  senderType;
      }
      return message;
    } catch (e) {
      return null;
    }
  }

  static getId(Map message) {
    try {
      if(message is List) {
        return message[1];
      }
      return message['id'];
    } catch (e) {
      return null;
    }
  }

  static getAction(Map message) {
    try {
      if(message is List) {
        return message[2];
      }
      return message['action'];
    } catch (e) {
      return null;
    }
  }

  static getPayload(Map message) {
    try {
      if(message is List) {
        return message[3];
      }
      return message['payload'];
    } catch (e) {
      return null;
    }
  }

  static getMessage(Map message) {
    try {
      return message['message'];
    } catch (e) {
      return null;
    }
  }

  static isValidMessage(var message) {
    return (message is String || message is List);
  }
}
