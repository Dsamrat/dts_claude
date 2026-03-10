//lib/notifications/web_notification_handler.dart
abstract class WebNotificationHandler {
  Future<void> requestPermission();
  void listenForClicks(void Function(String screen) onClick);
}
