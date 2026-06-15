import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../core/models/meal.dart';
import '../../core/services/ai/meal_analysis.dart';
import '../../core/theme/app_theme.dart';
import 'pwa_chrome.dart';

class MealCard extends StatefulWidget {
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
  State<MealCard> createState() => _MealCardState();
}

class _MealCardState extends State<MealCard> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final meal = widget.meal;
    final time = _fmtTime(meal.timestamp);
    final pc = providerColor(context, meal.provider);
    final ingredients = _ingredients(meal.ingredients);

    return GestureDetector(
      onTap: () => setState(() => _open = !_open),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MealThumb(imagePath: meal.imagePath),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                meal.mealName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: c.text,
                                  fontFamily: 'Playfair Display',
                                  fontSize: 14,
                                  height: 1.3,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              meal.calories.round().toString(),
                              style: TextStyle(
                                color: c.accent,
                                fontFamily: 'DM Mono',
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              time,
                              style: TextStyle(color: c.muted, fontSize: 10),
                            ),
                            if (meal.provider != null) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: providerBg(context, meal.provider),
                                  borderRadius: BorderRadius.circular(3),
                                ),
                                child: Text(
                                  providerLabel(meal.provider).toUpperCase(),
                                  style: TextStyle(
                                    color: pc,
                                    fontSize: 9,
                                    letterSpacing: 0.5,
                                    height: 1,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            _TinyMacro('P', meal.protein, c.mint),
                            const SizedBox(width: 8),
                            _TinyMacro('C', meal.carbs, c.sky),
                            const SizedBox(width: 8),
                            _TinyMacro('F', meal.fat, c.peach),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            if (_open)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: c.border)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          vertical: 10, horizontal: 8),
                      decoration: BoxDecoration(
                        color: c.surface,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          _MacroDetail('Protein', meal.protein, c.mint),
                          _MacroDetail('Carbs', meal.carbs, c.sky),
                          _MacroDetail('Fat', meal.fat, c.peach),
                          _MacroDetail('Fiber', meal.fiber, c.plum),
                        ],
                      ),
                    ),
                    if (ingredients.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'INGREDIENT BREAKDOWN',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 9,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      ...ingredients.map(
                        (item) => Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.label,
                                style: TextStyle(
                                  color: c.text,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _ingredientNutrition(item),
                                style: TextStyle(
                                  color: c.muted,
                                  fontSize: 10,
                                  fontFamily: 'DM Mono',
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    if (meal.portionNote != null &&
                        meal.portionNote!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: c.accent.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                          border: Border(left: BorderSide(color: pc, width: 2)),
                        ),
                        child: Text(
                          meal.portionNote!,
                          style: TextStyle(
                            color: c.muted,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                    if (meal.description != null &&
                        meal.description!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          text: 'Note: ',
                          style: TextStyle(color: c.accent),
                          children: [
                            TextSpan(
                              text: meal.description!,
                              style: TextStyle(color: c.muted),
                            ),
                          ],
                        ),
                        style: const TextStyle(fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (widget.onLogAgain != null) ...[
                          Expanded(
                            child: PwaButton(
                              label: 'Log again',
                              color: pc,
                              height: 38,
                              onPressed: widget.onLogAgain,
                            ),
                          ),
                          const SizedBox(width: 10),
                        ],
                        if (widget.onEdit != null)
                          Expanded(
                            flex: 2,
                            child: PwaButton(
                              label: 'Modify / re-analyze',
                              color: pc,
                              filled: false,
                              height: 38,
                              onPressed: widget.onEdit,
                            ),
                          ),
                        if (widget.onDelete != null) ...[
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 78,
                            child: PwaButton(
                              label: 'Delete',
                              color: c.danger,
                              filled: false,
                              height: 38,
                              onPressed: widget.onDelete,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  List<MealIngredient> _ingredients(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final parsed = raw.startsWith('[') ? raw : '[]';
      final list = List<Object?>.from(jsonDecode(parsed) as List);
      return list
          .map(MealIngredient.fromJson)
          .where((e) => e.name.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  String _ingredientNutrition(MealIngredient item) {
    if (!item.hasNutrition) return 'Nutrition not itemized';
    final parts = <String>[];
    if (item.calories != null) parts.add('${item.calories!.round()} kcal');
    if (item.protein != null) parts.add('${item.protein!.toStringAsFixed(0)}P');
    if (item.carbs != null) parts.add('${item.carbs!.toStringAsFixed(0)}C');
    if (item.fat != null) parts.add('${item.fat!.toStringAsFixed(0)}F');
    if (item.fiber != null) parts.add('${item.fiber!.toStringAsFixed(0)}Fi');
    return parts.join('  ·  ');
  }

  String _fmtTime(int ts) {
    final dt = DateTime.fromMillisecondsSinceEpoch(ts);
    final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final m = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $ampm';
  }
}

class _MealThumb extends StatelessWidget {
  final String? imagePath;

  const _MealThumb({this.imagePath});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    if (imagePath != null) {
      return Image.file(
        File(imagePath!),
        width: 80,
        height: 80,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _Placeholder(color: c.surface),
      );
    }
    return _Placeholder(color: c.surface);
  }
}

class _Placeholder extends StatelessWidget {
  final Color color;

  const _Placeholder({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      height: 80,
      color: color,
      alignment: Alignment.center,
      child: const Text('🍽', style: TextStyle(fontSize: 26)),
    );
  }
}

class _TinyMacro extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _TinyMacro(
    this.label,
    this.value,
    this.color,
  );

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label ${value.toStringAsFixed(0)}g',
      style: TextStyle(
        color: color,
        fontFamily: 'DM Mono',
        fontSize: 11,
      ),
    );
  }
}

class _MacroDetail extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroDetail(
    this.label,
    this.value,
    this.color,
  );

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: Column(
        children: [
          Text(
            '${value.toStringAsFixed(0)}g',
            style: TextStyle(
              color: color,
              fontFamily: 'DM Mono',
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              color: c.muted,
              fontSize: 9,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
