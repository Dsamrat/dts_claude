//lib/notifications/web_notification_handler_mobile.dart
import 'web_notification_handler.dart';

class WebNotificationHandlerImpl implements WebNotificationHandler {
  @override
  Future<void> requestPermission() async {}

  @override
  void listenForClicks(void Function(String screen) onClick) {}
}
