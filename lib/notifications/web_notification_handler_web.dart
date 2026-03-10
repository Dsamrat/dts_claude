//lib/notifications/web_notification_handler_web.dart
import 'dart:html' as html;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'web_notification_handler.dart';

/*
class WebNotificationHandlerImpl implements WebNotificationHandler {
  @override
  Future<void> requestPermission() async {
    final permission = await html.Notification.requestPermission();
    if (permission == 'granted') {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey:
            'BCbkuIRCk6b7V3R3NchANq0Q7HdTCmQL1FOk3YnWJjkhXtwZyODfCd8Owl9U-ri6Y53ANExN2B_zJTE4H4ovraY',
      );
      print('🌐 Web FCM Token: $token');
    }
  }

  @override
  void listenForClicks(void Function(String screen) onClick) {
    html.window.navigator.serviceWorker?.addEventListener('message', (event) {
      final messageEvent = event as html.MessageEvent;
      final data = messageEvent.data;

      if (data != null && data['screen'] != null) {
        onClick(data['screen']);
      }
    });
  }
}
*/
class WebNotificationHandlerImpl implements WebNotificationHandler {
  @override
  Future<void> requestPermission() async {
    final settings = await FirebaseMessaging.instance.requestPermission();

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      final token = await FirebaseMessaging.instance.getToken(
        vapidKey:
            'BCbkuIRCk6b7V3R3NchANq0Q7HdTCmQL1FOk3YnWJjkhXtwZyODfCd8Owl9U-ri6Y53ANExN2B_zJTE4H4ovraY',
      );
      print('🌐 Web FCM Token: $token');
    }
  }

  @override
  void listenForClicks(void Function(String screen) onClick) {
    // Clicks handled in firebase-messaging-sw.js
  }
}
