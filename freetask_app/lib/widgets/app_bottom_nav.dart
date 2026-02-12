import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

enum AppTab { chats, jobs, home }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentTab});

  final AppTab currentTab;

  void _onDestinationSelected(BuildContext context, int index) {
    final tab = AppTab.values[index];
    switch (tab) {
      case AppTab.chats:
        context.go('/chats');
        break;
      case AppTab.jobs:
        context.go('/jobs');
        break;
      case AppTab.home:
        context.go('/home');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: NavigationBar(
        height: 68,
        selectedIndex: currentTab.index,
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
            label: 'Chat',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Services',
          ),
        ],
      ),
    );
  }
}
