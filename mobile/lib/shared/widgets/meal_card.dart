import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/meal.dart';
import '../../core/theme/app_theme.dart';
import 'macro_row.dart';

class MealCard extends StatelessWidget {
  final Meal meal;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback? onLogAgain;

  const MealCard({
    super.key,
    required this.meal,
    this.onEdit,
    this.onDelete,
    this.onLogAgain,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final time = _fmtTime(meal.timestamp);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (meal.imagePath != null)
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(14)),
              child: Image.file(
                File(meal.imagePath!),
                width: double.infinity,
                height: 180,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        meal.mealName,
                        style: TextStyle(
                          color: c.text,
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    Text(
                      time,
                      style: TextStyle(color: c.muted, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                MacroRow(
                  calories: meal.calories,
                  protein: meal.protein,
                  carbs: meal.carbs,
                  fat: meal.fat,
                  fiber: meal.fiber,
                ),
                if (meal.portionNote != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    meal.portionNote!,
                    style: TextStyle(color: c.muted, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (onEdit != null)
                      _ActionBtn(
                          label: 'Edit',
                          icon: Icons.edit_outlined,
                          color: c.muted,
                          onTap: onEdit!),
                    if (onLogAgain != null) ...[
                      const SizedBox(width: 8),
                      _ActionBtn(
                          label: 'Log again',
                          icon: Icons.repeat,
                          color: c.accent,
                          onTap: onLogAgain!),
                    ],
                    const Spacer(),
                    if (onDelete != null)
                      _ActionBtn(
                          label: 'Delete',
                          icon: Icons.delete_outline,
                          color: c.danger,
                          onTap: onDelete!),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmtTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(color: color, fontSize: 13)),
        ],
      ),
    );
  }
}
