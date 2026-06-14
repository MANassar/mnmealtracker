import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';

import '../features/coach/coach_screen.dart';
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
        GoRoute(
          path: '/coach',
          pageBuilder: (context, state) =>
              const NoTransitionPage(child: CoachScreen()),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GlassScaffold(
      backgroundColor: c.bg,
      statusBarStyle: GlassStatusBarStyle.auto,
      bottomBar: GlassBottomBar(
        tabs: const [
          GlassBottomBarTab(
            label: 'Home',
            icon: Icon(CupertinoIcons.house),
            activeIcon: Icon(CupertinoIcons.house_fill),
          ),
          GlassBottomBarTab(
            label: 'History',
            icon: Icon(CupertinoIcons.list_bullet),
          ),
          GlassBottomBarTab(
            label: 'Weight',
            icon: Icon(Icons.monitor_weight_outlined),
            activeIcon: Icon(Icons.monitor_weight),
          ),
          GlassBottomBarTab(
            label: 'Coach',
            icon: Icon(CupertinoIcons.sparkles),
          ),
        ],
        selectedIndex: currentIndex,
        onTabSelected: (i) => _onTap(context, i),
        selectedIconColor: c.accent,
        unselectedIconColor: c.muted,
        settings: isDark
            ? const LiquidGlassSettings(
                thickness: 30,
                blur: 3,
                chromaticAberration: 0.3,
                lightIntensity: 0.4,
                refractiveIndex: 1.59,
                saturation: 0.7,
                ambientStrength: 0.0,
                lightAngle: 0.75 * math.pi,
                glassColor: Color(0x14FFFFFF),
              )
            : null,
        extraButton: GlassBottomBarExtraButton(
          icon: const Icon(CupertinoIcons.add),
          label: 'Add Meal',
          onTap: () => context.push('/add'),
          iconColor: isDark ? Colors.white : AppColors.darkBg,
        ),
      ),
      body: child,
    );
  }

  int _indexForLocation(String location) {
    if (location.startsWith('/history')) return 1;
    if (location.startsWith('/weight')) return 2;
    if (location.startsWith('/coach')) return 3;
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
        context.go('/coach');
        break;
    }
  }
}
