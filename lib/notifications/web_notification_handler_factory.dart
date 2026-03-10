//lib/notifications/web_notification_handler_factory.dart
export 'web_notification_handler_mobile.dart'
    if (dart.library.html) 'web_notification_handler_web.dart';
