library isolatesystem.message.SenderType;

class SenderType {
  static const String ISOLATE_SYSTEM = "senderType.isolate_system";
  static const String CONTROLLER = "senderType.controller";
  static const String MQS = "senderType.mqs"; // message queuing system

  static const String ROUTER = "senderType.router";
  static const String WORKER = "senderType.worker";
  static const String FILE_MONITOR = "senderType.file_monitor";
  static const String PROXY = "senderType.proxy";

  static const String SELF = "senderType.self"; // TODO: remove
  static const String EXTERNAL = "senderType.external"; // TODO: remove

  static const String DIRECT = "senderType.direct";
}
