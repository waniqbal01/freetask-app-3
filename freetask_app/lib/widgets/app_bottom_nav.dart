import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

enum AppTab { chats, jobs, home }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentTab});

  final AppTab currentTab;

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == 0) {
      // By default, the Home tab goes to chats. The user can toggle to marketplace from there.
      context.go('/chats');
    } else if (index == 1) {
      context.go('/jobs');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Both chats and home tab will highlight the first 'Home' button
    final int selectedIndex = currentTab == AppTab.jobs ? 1 : 0;

    return SafeArea(
      top: false,
      child: NavigationBar(
        height: 68,
        selectedIndex: selectedIndex,
        elevation: 8,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.08),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (int index) =>
            _onDestinationSelected(context, index),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.chat_bubble_outline),
            selectedIcon: Icon(Icons.chat_bubble_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
        ],
      ),
    );
  }
}
