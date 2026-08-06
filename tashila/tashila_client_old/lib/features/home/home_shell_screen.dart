import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:tashila_client/features/history/history_screen.dart';
import 'package:tashila_client/features/map_booking/booking_screen.dart';
import 'package:tashila_client/features/profile_settings/profile_settings_screen.dart';

class HomeShellScreen extends StatefulWidget {
  const HomeShellScreen({super.key});

  @override
  State<HomeShellScreen> createState() => _HomeShellScreenState();
}

class _HomeShellScreenState extends State<HomeShellScreen> {
  int currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = const [BookingScreen(), HistoryScreen(), ProfileSettingsScreen()];
    return Scaffold(
      body: tabs[currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: currentIndex,
        onDestinationSelected: (value) => setState(() => currentIndex = value),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.map), label: 'book'.tr()),
          NavigationDestination(icon: const Icon(Icons.history), label: 'history'.tr()),
          NavigationDestination(icon: const Icon(Icons.person), label: 'profile'.tr()),
        ],
      ),
    );
  }
}
