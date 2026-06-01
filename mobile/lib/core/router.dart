import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/history/history_screen.dart';
import '../features/meals/add_meal_screen.dart';
import '../features/meals/today_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/weight/weight_screen.dart';
import 'models/meal.dart';
import 'theme/app_theme.dart';

final appRouter = GoRouter(
  initialLocation: '/today',
  routes: [
    ShellRoute(
      builder: (context, state, child) =>
          AppShell(location: state.uri.path, child: child),
      routes: [
        GoRoute(
          path: '/today',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: TodayScreen()),
        ),
        GoRoute(
          path: '/history',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: HistoryScreen()),
        ),
        GoRoute(
          path: '/weight',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: WeightScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/settings',
      pageBuilder: (context, state) => const MaterialPage(
        fullscreenDialog: true,
        child: SettingsScreen(),
      ),
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
  final String location;
  final Widget child;
  const AppShell({super.key, required this.location, required this.child});

  @override
  Widget build(BuildContext context) {
    final currentIndex = _indexForLocation(location);
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: child,
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add'),
        backgroundColor: c.accent,
        foregroundColor: AppColors.darkBg,
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.add, size: 30),
      ),
      bottomNavigationBar: _PwaTabBar(
        currentIndex: currentIndex,
        onTap: (i) => _onTap(context, i),
      ),
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/weight')) return 2;
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
    }
  }
}

class _PwaTabBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _PwaTabBar({
    required this.currentIndex,
    required this.onTap,
  });

  static const _items = [
    ('◉', 'Home'),
    ('≡', 'History'),
    ('⚖', 'Weight'),
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return SafeArea(
      top: false,
      child: Container(
        height: 64,
        decoration: BoxDecoration(
          color: c.bg.withValues(alpha: 0.97),
          border: Border(top: BorderSide(color: c.border)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              blurRadius: 20,
              offset: const Offset(0, -8),
            ),
          ],
        ),
        child: Row(
          children: List.generate(_items.length, (i) {
            final active = i == currentIndex;
            final item = _items[i];
            return Expanded(
              child: InkWell(
                onTap: () => onTap(i),
                child: Container(
                  color: active
                      ? c.accent.withValues(alpha: 0.12)
                      : Colors.transparent,
                  padding: const EdgeInsets.fromLTRB(0, 10, 0, 8),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        item.$1,
                        style: TextStyle(
                          color: active ? c.accent : c.muted,
                          fontSize: 17,
                          height: 1,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$2.toUpperCase(),
                        style: TextStyle(
                          color: active ? c.accent : c.muted,
                          fontSize: 10,
                          fontWeight:
                              active ? FontWeight.w700 : FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: active ? 18 : 0,
                        height: 2,
                        decoration: BoxDecoration(
                          color: c.accent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}
