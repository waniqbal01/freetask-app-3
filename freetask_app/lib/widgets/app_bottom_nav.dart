import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_theme.dart';

enum AppTab { chats, market, jobs, profile }

class AppBottomNav extends StatelessWidget {
  const AppBottomNav({super.key, required this.currentTab});

  final AppTab currentTab;

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == 0) {
      context.go('/chats');
    } else if (index == 1) {
      context.go('/home');
    } else if (index == 2) {
      context.go('/jobs');
    } else if (index == 3) {
      context.go('/profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    int selectedIndex;
    switch (currentTab) {
      case AppTab.chats:
        selectedIndex = 0;
        break;
      case AppTab.market:
        selectedIndex = 1;
        break;
      case AppTab.jobs:
        selectedIndex = 2;
        break;
      case AppTab.profile:
        selectedIndex = 3;
        break;
    }

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
            icon: Icon(Icons.store_mall_directory_outlined),
            selectedIcon: Icon(Icons.store_mall_directory_rounded),
            label: 'Market',
          ),
          NavigationDestination(
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work_rounded),
            label: 'Jobs',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
