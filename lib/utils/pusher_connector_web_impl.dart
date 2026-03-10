// lib/utils/pusher_connector_web_impl.dart

import 'dart:js' as js;
import 'pusher_connector_interface.dart';

class PusherConnectorWeb implements IPusherConnector {
  @override
  void initPusherWeb(
    String channelName, // Use the new parameter
    String eventName, // Use the new parameter
    Function(dynamic raw) handlePusherEvent,
  ) {
    js.context['pusherCallbackWeb'] = (raw) => handlePusherEvent(raw);

    // Construct the full channel name dynamically

    js.context.callMethod('pusherConnect', [
      channelName, // Dynamic channel name
      eventName, // Dynamic event name
      "pusherCallbackWeb",
    ]);
  }
}

// Provide the factory function
IPusherConnector createPusherConnector() => PusherConnectorWeb();
