// lib/utils/pusher_connector_interface.dart

abstract class IPusherConnector {
  // Assuming this is your interface/abstract class
  void initPusherWeb(
    String channelName,
    String eventName, // New parameter for event name
    Function(dynamic raw) handlePusherEvent,
  );
}

// Factory function: implemented in platform-specific files
IPusherConnector createPusherConnector() =>
    throw UnsupportedError('Cannot create a PusherConnector for this platform');
