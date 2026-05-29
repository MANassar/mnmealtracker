import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/meals/add_meal_screen.dart';
import '../features/meals/today_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/weight/weight_screen.dart';
import 'models/meal.dart';

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child),
      routes: [
        GoRoute(
          path: '/today',
          pageBuilder: (context, state) =>
              NoTransitionPage(child: TodayScreen()),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) =>
              NoTransitionPage(child: const HistoryScreen()),
        ),
        GoRoute(
          path: '/weight',
          pageBuilder: (context, state) =>
              NoTransitionPage(child: const WeightScreen()),
        ),
        GoRoute(
          path: '/settings',
          pageBuilder: (context, state) =>
              NoTransitionPage(child: const SettingsScreen()),
        ),
      ],
    ),
    // Add/edit meal — full-screen, outside the shell
    GoRoute(
      path: '/add',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>?;
        return AddMealScreen(
          editingMeal: extra?['editingMeal'] as Meal?,
          repeatMeal: extra?['repeatMeal'] as Meal?,
          returnPath: extra?['returnPath'] as String? ?? '/today',
        );
      },
    ),
  ],
);

class AppShell extends StatelessWidget {
  final Widget child;
  const AppShell({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouter.of(context).location;
    final currentIndex = _indexForLocation(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.today_outlined),
            activeIcon: Icon(Icons.today),
            label: 'Today',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.history_outlined),
            activeIcon: Icon(Icons.history),
            label: 'History',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.monitor_weight_outlined),
            activeIcon: Icon(Icons.monitor_weight),
            label: 'Weight',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/weight')) return 2;
    if (location.startsWith('/settings')) return 3;
    return 0;
  }

  void _onTap(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/today');
        break;
      case 1:
        context.go('/history');
        break;
      case 2:
        context.go('/weight');
        break;
      case 3:
        context.go('/settings');
        break;
    }
  }
}
