import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/meal.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/meal_card.dart';
import '../../shared/widgets/pwa_chrome.dart';

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealsProvider);
    final settings = ref.watch(settingsProvider);
    final c = context.appColors;

    final totalCals = meals.fold<double>(0.0, (s, m) => s + m.calories);
    final totalP = meals.fold<double>(0.0, (s, m) => s + m.protein);
    final totalC = meals.fold<double>(0.0, (s, m) => s + m.carbs);
    final totalF = meals.fold<double>(0.0, (s, m) => s + m.fat);
    final goalCalories = settings.goalCalories ?? 1800;
    final goalProtein = settings.goalProtein ?? 150;
    final goalCarbs = settings.goalCarbs ?? 180;
    final goalFat = settings.goalFat ?? 60;
    final remaining = goalCalories - totalCals;
    final sortedMeals = [...meals]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          PwaTopBar(
            eyebrow: _todayLabel(),
            onSettings: () => context.push('/settings'),
          ),
          Expanded(
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      const SizedBox(height: 16),
                      CalorieRing(
                        consumed: totalCals,
                        target: goalCalories,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        remaining >= 0
                            ? '${remaining.round()} kcal remaining'
                            : '${remaining.abs().round()} kcal over target',
                        style: TextStyle(
                          color: remaining >= 0 ? c.mint : c.danger,
                          fontSize: 12,
                          fontFamily: 'DM Mono',
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
                        child: Row(
                          children: [
                            MacroProgressBar(
                              label: 'Protein',
                              value: totalP,
                              max: goalProtein,
                              color: c.mint,
                            ),
                            const SizedBox(width: 14),
                            MacroProgressBar(
                              label: 'Carbs',
                              value: totalC,
                              max: goalCarbs,
                              color: c.sky,
                            ),
                            const SizedBox(width: 14),
                            MacroProgressBar(
                              label: 'Fat',
                              value: totalF,
                              max: goalFat,
                              color: c.peach,
                            ),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: Text(
                                meals.isEmpty
                                    ? 'No meals logged yet'
                                    : '${meals.length} Meal${meals.length > 1 ? 's' : ''} today',
                                style: TextStyle(
                                  color: c.muted,
                                  fontFamily: 'Playfair Display',
                                  fontSize: 12,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                            if (meals.isNotEmpty)
                              Text(
                                '${totalP.toStringAsFixed(0)}P·${totalC.toStringAsFixed(0)}C·${totalF.toStringAsFixed(0)}F',
                                style: TextStyle(
                                  color: c.muted,
                                  fontSize: 10,
                                  fontFamily: 'DM Mono',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (meals.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 120),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '🍽',
                              style: TextStyle(
                                fontSize: 36,
                                color: c.muted.withValues(alpha: 0.6),
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text.rich(
                              TextSpan(
                                text: 'Tap ',
                                children: [
                                  TextSpan(
                                    text: '+',
                                    style: TextStyle(color: c.accent),
                                  ),
                                  const TextSpan(
                                      text: ' to log your first meal'),
                                ],
                              ),
                              style: TextStyle(color: c.muted, fontSize: 14),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, i) {
                          final meal = sortedMeals[i];
                          return MealCard(
                            meal: meal,
                            onEdit: () => context.push('/add', extra: {
                              'editingMeal': meal,
                              'returnPath': '/today',
                            }),
                            onDelete: () => _confirmDelete(context, ref, meal),
                            onLogAgain: () => context.push('/add', extra: {
                              'repeatMeal': meal,
                              'returnPath': '/today',
                            }),
                          );
                        },
                        childCount: sortedMeals.length,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}'
        .toUpperCase();
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Meal meal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${meal.mealName}" from today?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(mealsProvider.notifier).delete(meal.id);
    }
  }
}
