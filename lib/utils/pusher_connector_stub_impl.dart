// lib/utils/pusher_connector_stub_impl.dart

import 'pusher_connector_interface.dart';

class PusherConnectorStub implements IPusherConnector {
  @override
  void initPusherWeb(
    String channelName, // Use the new parameter
    String eventName, // Use the new parameter
    Function(dynamic raw) handlePusherEvent,
  ) {
    // Do nothing on mobile
  }
}

// Provide the factory function
IPusherConnector createPusherConnector() => PusherConnectorStub();
