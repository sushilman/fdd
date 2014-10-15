library messageQueuingSystem.message.MessageUtil;

class MQSMessageUtil {
  static createEnqueueMessage(String targetQueue, var payload) {
    Map enqueueMessage = {'targetQueue':targetQueue, 'action':"action.enqueue", 'payload':payload};
    return enqueueMessage;
  }

  static createDequeueMessage(String fromQueue) {
    Map dequeueMessage = {'targetQueue':fromQueue, 'action':"action.dequeue"};
    return dequeueMessage;
  }

  static getTargetQueue(Map message) {
    return message.containsKey('targetQueue') ? message['targetQueue'] :  null;
  }

  static getAction(Map message) {
    return message.containsKey('action') ? message['action'] : null;
  }

  static getPayload(Map message) {
    return message.containsKey('payload') ? message['payload'] : null;
  }
}
