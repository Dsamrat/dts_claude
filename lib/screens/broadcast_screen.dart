import 'package:flutter/material.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import '../widgets/navbar.dart';
import '../widgets/drawer.dart';

class BroadCastScreen extends StatefulWidget {
  const BroadCastScreen({super.key});

  @override
  State<BroadCastScreen> createState() => _BroadCastScreenState();
}

class _BroadCastScreenState extends State<BroadCastScreen> {
  final PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();
  late PusherChannel invoiceChannel;

  @override
  void initState() {
    super.initState();
    initPusher();
  }

  Future<void> initPusher() async {
    try {
      await pusher.init(
        apiKey: 'localkey',
        cluster: 'mt1', // ignored for local
        authEndpoint: 'http://192.168.0.106:8000/broadcasting/auth',

        onConnectionStateChange: (current, previous) {
          debugPrint("WebSocket state: $previous → $current");
        },
        onError: (message, code, exception) {
          debugPrint("Pusher error: $message (code: $code) $exception");
        },
        onEvent: (PusherEvent event) {
          debugPrint("📦 Received event: ${event.eventName} => ${event.data}");
        },
      );

      await pusher.connect();

      invoiceChannel = await pusher.subscribe(channelName: 'invoices');

      debugPrint("🎉 Pusher initialized and subscribed successfully!");
    } catch (e) {
      debugPrint("❌ Error initializing Pusher: $e");
    }
  }

  @override
  void dispose() {
    invoiceChannel.unsubscribe();
    pusher.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2F1),
      appBar: Navbar(title: "Dashboard"),
      drawer: ArgonDrawer(currentPage: "Home"),
      body: const Center(
        child: Text(
          "No records found",
          style: TextStyle(fontSize: 16, color: Colors.grey),
        ),
      ),
    );
  }
}
