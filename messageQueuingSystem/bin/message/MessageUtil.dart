library messageQueuingSystem.message.MessageUtil;

import '../action/Action.dart';


class MessageUtil {
  static createEnqueueMessage(String targetQueue, var payload) {
    Map enqueueMessage = {'targetQueue':targetQueue, 'action':Action.ENQUEUE, 'payload':payload};
    return enqueueMessage;
  }

  static createDequeueMessage(String fromQueue) {
    Map dequeueMessage = {'targetQueue':fromQueue, 'action':Action.DEQUEUE};
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
