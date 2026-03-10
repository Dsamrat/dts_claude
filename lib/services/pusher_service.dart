import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:flutter/material.dart';

class PusherService {
  final String apiKey;
  final String cluster;
  final String authEndpoint;
  final String userToken;
  final Map<String, Function(dynamic)> _eventCallbacks = {};

  PusherService({
    required this.apiKey,
    required this.cluster,
    required this.authEndpoint,
    required this.userToken,
  });

  PusherChannelsFlutter? _pusher;

  void on(String channelName, String eventName, Function(dynamic) callback) {
    _eventCallbacks['$channelName:$eventName'] = callback;
  }

  Future<void> init() async {
    _pusher = PusherChannelsFlutter.getInstance();

    try {
      await _pusher!.init(
        apiKey: apiKey,
        cluster: cluster,

        authEndpoint: null,
        authTransport: null,
        onAuthorizer: null,
        enabledTransports: ['ws'],
        onEvent: (event) {
          debugPrint(
            "📡 Event received on channel '${event.channelName}': ${event.eventName}, Data: ${event.data}",
          );
          final key = '${event.channelName}:${event.eventName}';
          if (_eventCallbacks.containsKey(key)) {
            try {
              _eventCallbacks[key]!(event.data);
            } catch (e) {
              debugPrint("❌ Error during callback for '$key': $e");
            }
          } else {
            debugPrint("ℹ️ No callback registered for event '$key'.");
          }
        },
        onConnectionStateChange: (currentState, previousState) {
          debugPrint(
            "🔄 Connection changed from $previousState to $currentState",
          );
        },
        onError: (message, code, exception) {
          debugPrint(
            "❗ Pusher error: $message (code: $code), Exception: $exception",
          );
        },
      );

      // Subscribe to all unique channels
      final uniqueChannels =
          _eventCallbacks.keys.map((key) => key.split(':')[0]).toSet();
      for (final channel in uniqueChannels) {
        await _pusher!.subscribe(channelName: channel);
      }

      await _pusher!.connect();
    } catch (e) {
      debugPrint("❌ Failed to initialize or connect to Pusher: $e");
    }
  }

  Future<void> disconnect(String channelName) async {
    await _pusher?.unsubscribe(channelName: channelName);
    // Optionally remove callbacks associated with this channel
    _eventCallbacks.removeWhere(
      (key, value) => key.startsWith('$channelName:'),
    );
    debugPrint("🔌 Unsubscribed from channel '$channelName'.");
  }

  Future<void> disconnectAll() async {
    await _pusher?.disconnect();
    _eventCallbacks.clear();
    debugPrint("🔌 Disconnected from Pusher and cleared all callbacks.");
  }
}
