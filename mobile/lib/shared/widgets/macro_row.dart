import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

class MacroRow extends StatelessWidget {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final double? goalCalories;
  final double? goalProtein;
  final double? goalCarbs;
  final double? goalFat;

  const MacroRow({
    super.key,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.goalCalories,
    this.goalProtein,
    this.goalCarbs,
    this.goalFat,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: [
        _MacroChip(
            value: calories,
            goal: goalCalories,
            label: 'kcal',
            color: c.accent),
        const SizedBox(width: 8),
        _MacroChip(
            value: protein, goal: goalProtein, label: 'P', color: c.mint),
        const SizedBox(width: 8),
        _MacroChip(value: carbs, goal: goalCarbs, label: 'C', color: c.sky),
        const SizedBox(width: 8),
        _MacroChip(value: fat, goal: goalFat, label: 'F', color: c.peach),
        const SizedBox(width: 8),
        _MacroChip(value: fiber, label: 'Fi', color: c.plum),
      ],
    );
  }
}

class _MacroChip extends StatelessWidget {
  final double value;
  final double? goal;
  final String label;
  final Color color;

  const _MacroChip({
    required this.value,
    required this.label,
    required this.color,
    this.goal,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final display =
        value >= 10 ? value.toInt().toString() : value.toStringAsFixed(1);
    final overGoal = goal != null && goal! > 0 && value > goal!;
    final activeColor = overGoal ? c.danger : color;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: overGoal ? c.danger : c.muted,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          display,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: activeColor,
          ),
        ),
      ],
    );
  }
}
