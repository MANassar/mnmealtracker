import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/models/meal.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/macro_row.dart';
import '../../shared/widgets/meal_card.dart';

class TodayScreen extends ConsumerWidget {
  TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meals = ref.watch(todayMealsProvider);
    final settings = ref.watch(settingsProvider);
    final c = context.appColors;

    final totalCals = meals.fold<double>(0.0, (s, m) => s + m.calories);
    final totalP = meals.fold<double>(0.0, (s, m) => s + m.protein);
    final totalC = meals.fold<double>(0.0, (s, m) => s + m.carbs);
    final totalF = meals.fold<double>(0.0, (s, m) => s + m.fat);
    final totalFi = meals.fold<double>(0.0, (s, m) => s + m.fiber);

    final hasGoals = settings.goalCalories != null ||
        settings.goalProtein != null ||
        settings.goalCarbs != null ||
        settings.goalFat != null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        title: Text(
          'Today',
          style: TextStyle(color: c.text, fontWeight: FontWeight.w600),
        ),
        backgroundColor: c.surface,
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: c.muted),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // Summary card
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _todayLabel(),
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  MacroRow(
                    calories: totalCals,
                    protein: totalP,
                    carbs: totalC,
                    fat: totalF,
                    fiber: totalFi,
                    goalCalories: settings.goalCalories,
                    goalProtein: settings.goalProtein,
                    goalCarbs: settings.goalCarbs,
                    goalFat: settings.goalFat,
                  ),
                  if (hasGoals && settings.goalCalories != null) ...[
                    const SizedBox(height: 12),
                    _CalorieBar(
                      consumed: totalCals,
                      goal: settings.goalCalories!,
                      color: c.accent,
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Meal list
          if (meals.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.restaurant_menu,
                        size: 48, color: c.muted.withOpacity(0.4)),
                    const SizedBox(height: 12),
                    Text(
                      'No meals logged today',
                      style: TextStyle(color: c.muted),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tap + to log your first meal',
                      style: TextStyle(color: c.muted, fontSize: 13),
                    ),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, i) {
                    final meal = meals[i];
                    return MealCard(
                      meal: meal,
                      onEdit: () => context.push('/add',
                          extra: {
                            'editingMeal': meal,
                            'returnPath': '/today',
                          }),
                      onDelete: () => _confirmDelete(context, ref, meal),
                    );
                  },
                  childCount: meals.length,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/add'),
        backgroundColor: c.accent,
        foregroundColor: c.bg,
        icon: const Icon(Icons.add),
        label: const Text('Log meal'),
      ),
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday',
      'Sunday'
    ];
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${weekdays[now.weekday - 1]}, ${now.day} ${months[now.month - 1]}';
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Meal meal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${meal.mealName}" from today?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(mealsProvider.notifier).delete(meal.id);
    }
  }
}

class _CalorieBar extends StatelessWidget {
  final double consumed;
  final double goal;
  final Color color;

  const _CalorieBar({
    required this.consumed,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pct = (consumed / goal).clamp(0.0, 1.0);
    final over = consumed > goal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('${consumed.toInt()} / ${goal.toInt()} kcal',
                style: TextStyle(
                    color: over ? c.danger : c.muted, fontSize: 12)),
            Text(
              over
                  ? '+${(consumed - goal).toInt()} over'
                  : '${(goal - consumed).toInt()} left',
              style: TextStyle(
                  color: over ? c.danger : c.muted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: c.border,
            valueColor: AlwaysStoppedAnimation(over ? c.danger : color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }
}
