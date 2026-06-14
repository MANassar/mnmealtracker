import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/meal.dart';
import '../../core/models/weight_entry.dart';
import '../../core/providers.dart';
import '../../core/services/ai/meal_analysis.dart';
import '../../core/theme/app_theme.dart';

class CoachScreen extends ConsumerStatefulWidget {
  const CoachScreen({super.key});

  @override
  ConsumerState<CoachScreen> createState() => _CoachScreenState();
}

class _CoachScreenState extends ConsumerState<CoachScreen> {
  bool _loading = false;
  String? _error;
  CoachPlan? _plan;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final meals = ref.watch(mealsProvider);
    final weights = ref.watch(weightsProvider);
    final todayMeals = ref.watch(todayMealsProvider);
    final c = context.appColors;
    final totals = _totals(todayMeals);
    final targets = _targets(settings);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Coach',
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Playfair Display',
                            fontSize: 24,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _timeLabel(DateTime.now()).toUpperCase(),
                          style: TextStyle(
                            color: c.muted,
                            fontSize: 10,
                            letterSpacing: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => context.push('/settings'),
                    icon: Icon(Icons.settings, color: c.muted),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
              children: [
                _DailyFitCard(totals: totals, targets: targets),
                const SizedBox(height: 12),
                _ContextCard(
                  mealCount: meals.length,
                  latestWeight: _latestWeight(weights),
                  settings: settings,
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: _loading
                      ? null
                      : () => _getCoachPlan(settings, meals, weights),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                    backgroundColor: c.accent,
                    foregroundColor: AppColors.darkBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _loading ? 'Thinking...' : 'Suggest my next meal',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _ErrorCard(message: _error!),
                ],
                if (_plan != null) ...[
                  const SizedBox(height: 14),
                  _PlanCard(
                    plan: _plan!,
                    onLog: _logSuggestion,
                  ),
                  const SizedBox(height: 2),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () => _getCoachPlan(
                              settings,
                              meals,
                              weights,
                              append: true,
                            ),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Text(_loading ? 'Thinking...' : 'Suggest more'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _getCoachPlan(
      AppSettings settings, List<Meal> meals, List<WeightEntry> weights,
      {bool append = false}) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final plan = await ref.read(aiServiceProvider).coach(
            settings: settings,
            context: _coachContext(
              settings,
              meals,
              weights,
              existingSuggestions: append ? _plan?.suggestions : null,
            ),
          );
      if (!mounted) return;
      setState(() {
        _plan = append && _plan != null
            ? CoachPlan(
                summary:
                    _plan!.summary.isNotEmpty ? _plan!.summary : plan.summary,
                focus: plan.focus.isNotEmpty ? plan.focus : _plan!.focus,
                caution:
                    plan.caution.isNotEmpty ? plan.caution : _plan!.caution,
                suggestions: [..._plan!.suggestions, ...plan.suggestions],
              )
            : plan;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic> _coachContext(
      AppSettings settings, List<Meal> meals, List<WeightEntry> weights,
      {List<CoachSuggestion>? existingSuggestions}) {
    final now = DateTime.now();
    final today = _todayStr(now);
    final todayMeals = meals.where((m) => m.date == today).toList();
    final recentMeals = [...meals]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final latestWeight = _latestWeight(weights);
    final targets = _targets(settings);
    final consumed = _totals(todayMeals);

    return {
      'generatedAt': now.toIso8601String(),
      'localTime': {
        'hour': now.hour,
        'weekday': now.weekday,
        'label': _timeLabel(now),
      },
      'targets': targets,
      'consumedToday': consumed,
      'remainingToday': {
        'calories': targets['calories']! - consumed['calories']!,
        'protein': targets['protein']! - consumed['protein']!,
        'carbs': targets['carbs']! - consumed['carbs']!,
        'fat': targets['fat']! - consumed['fat']!,
      },
      'user': {
        'weightUnit': settings.weightUnit,
        'latestWeight': latestWeight == null
            ? null
            : {
                'kg': latestWeight.weight,
                'display': settings.weightUnit == 'lbs'
                    ? latestWeight.weight * 2.20462262
                    : latestWeight.weight,
                'unit': settings.weightUnit,
                'date': latestWeight.date,
              },
        'goalWeightKg': settings.goalWeight,
        'macroProfile': settings.macroProfile?.toJson(),
        'macroRecommendation': settings.macroRecommendation?.toJson(),
        'country': null,
        'fitness': {
          'available': false,
          'exercises': <String>[],
        },
      },
      'recentMeals': recentMeals.take(10).map(_mealContext).toList(),
      if (existingSuggestions != null && existingSuggestions.isNotEmpty)
        'alreadySuggestedMeals': existingSuggestions
            .map((suggestion) => {
                  'mealName': suggestion.mealName,
                  'calories': suggestion.calories,
                  'protein': suggestion.protein,
                  'carbs': suggestion.carbs,
                  'fat': suggestion.fat,
                })
            .toList(),
    };
  }

  Future<void> _logSuggestion(CoachSuggestion suggestion) async {
    final settings = ref.read(settingsProvider);
    final now = DateTime.now();
    final meal = Meal()
      ..uuid = const Uuid().v4()
      ..date = _todayStr(now)
      ..timestamp = now.millisecondsSinceEpoch
      ..mealName = suggestion.mealName
      ..calories = suggestion.calories
      ..protein = suggestion.protein
      ..carbs = suggestion.carbs
      ..fat = suggestion.fat
      ..fiber = suggestion.fiber
      ..provider = settings.provider
      ..confidence = 'medium'
      ..portionNote = _coachPortionNote(suggestion)
      ..description = 'Logged from Coach suggestion'
      ..ingredients = jsonEncode(suggestion.ingredients);

    await ref.read(mealsProvider.notifier).save(meal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged ${suggestion.mealName}')),
    );
  }

  String _coachPortionNote(CoachSuggestion suggestion) {
    final parts = <String>[
      if (suggestion.why.trim().isNotEmpty) suggestion.why.trim(),
      if (suggestion.nutritionBreakdown.isNotEmpty)
        'Macro math: ${suggestion.nutritionBreakdown.join(' | ')}',
      if (suggestion.steps.isNotEmpty) suggestion.steps.join(' '),
    ];
    return parts.join('\n');
  }

  Map<String, dynamic> _mealContext(Meal meal) => {
        'date': meal.date,
        'timestamp': DateTime.fromMillisecondsSinceEpoch(meal.timestamp)
            .toIso8601String(),
        'mealName': meal.mealName,
        'calories': meal.calories,
        'protein': meal.protein,
        'carbs': meal.carbs,
        'fat': meal.fat,
        'fiber': meal.fiber,
        'description': _shortText(meal.description, 120),
        'ingredients': _ingredients(meal.ingredients).take(5).toList(),
      };

  String? _shortText(String? value, int maxLength) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    if (trimmed.length <= maxLength) return trimmed;
    return '${trimmed.substring(0, maxLength).trim()}...';
  }

  List<String> _ingredients(String? raw) {
    if (raw == null || raw.trim().isEmpty) return [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is List) return parsed.map((e) => e.toString()).toList();
    } catch (_) {}
    return [];
  }

  Map<String, double> _targets(AppSettings settings) => {
        'calories': settings.goalCalories ?? 1800,
        'protein': settings.goalProtein ?? 150,
        'carbs': settings.goalCarbs ?? 180,
        'fat': settings.goalFat ?? 60,
      };

  Map<String, double> _totals(List<Meal> meals) => {
        'calories': meals.fold<double>(0, (s, m) => s + m.calories),
        'protein': meals.fold<double>(0, (s, m) => s + m.protein),
        'carbs': meals.fold<double>(0, (s, m) => s + m.carbs),
        'fat': meals.fold<double>(0, (s, m) => s + m.fat),
      };

  WeightEntry? _latestWeight(List<WeightEntry> weights) {
    if (weights.isEmpty) return null;
    final sorted = [...weights]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.first;
  }

  String _todayStr(DateTime now) =>
      '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  String _timeLabel(DateTime now) {
    final part = now.hour < 11
        ? 'morning'
        : now.hour < 15
            ? 'midday'
            : now.hour < 18
                ? 'afternoon'
                : 'evening';
    return '$part · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _friendlyError(Object e) {
    final text = e
        .toString()
        .replaceFirst('Exception: ', '')
        .replaceFirst(RegExp(r'Source stack:[\s\S]*'), '')
        .trim();
    return text.isEmpty ? 'Coach could not generate suggestions.' : text;
  }
}

class _DailyFitCard extends StatelessWidget {
  final Map<String, double> totals;
  final Map<String, double> targets;

  const _DailyFitCard({required this.totals, required this.targets});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final remaining = (targets['calories'] ?? 0) - (totals['calories'] ?? 0);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Today so far',
              style:
                  TextStyle(color: c.muted, fontSize: 10, letterSpacing: 1.2)),
          const SizedBox(height: 8),
          Text(
            remaining >= 0
                ? '${remaining.round()} kcal remaining'
                : '${remaining.abs().round()} kcal over target',
            style: TextStyle(
              color: remaining >= 0 ? c.mint : c.danger,
              fontSize: 22,
              fontFamily: 'DM Mono',
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _MiniMacro('P', totals['protein']!, targets['protein']!, c.mint),
              const SizedBox(width: 8),
              _MiniMacro('C', totals['carbs']!, targets['carbs']!, c.sky),
              const SizedBox(width: 8),
              _MiniMacro('F', totals['fat']!, targets['fat']!, c.peach),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniMacro extends StatelessWidget {
  final String label;
  final double value;
  final double target;
  final Color color;

  const _MiniMacro(this.label, this.value, this.target, this.color);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pct = target <= 0 ? 0.0 : (value / target).clamp(0.0, 1.0);
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$label ${value.round()}/${target.round()}g',
              style:
                  TextStyle(color: color, fontSize: 11, fontFamily: 'DM Mono')),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 4,
              backgroundColor: c.surface,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContextCard extends StatelessWidget {
  final int mealCount;
  final WeightEntry? latestWeight;
  final AppSettings settings;

  const _ContextCard({
    required this.mealCount,
    required this.latestWeight,
    required this.settings,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final displayWeight = latestWeight == null
        ? 'No weight yet'
        : settings.weightUnit == 'lbs'
            ? '${(latestWeight!.weight * 2.20462262).toStringAsFixed(1)} lbs'
            : '${latestWeight!.weight.toStringAsFixed(1)} kg';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(c),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip('Meals', '$mealCount logged'),
          _Chip('Weight', displayWeight),
          _Chip('Goal', settings.macroProfile?.goal ?? 'targets'),
          const _Chip('Fitness', 'not connected'),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final String value;

  const _Chip(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: c.border),
      ),
      child: Text(
        '$label · $value',
        style: TextStyle(color: c.muted, fontSize: 11),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final CoachPlan plan;
  final ValueChanged<CoachSuggestion> onLog;

  const _PlanCard({required this.plan, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.summary.isNotEmpty || plan.focus.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: _cardDecoration(c),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (plan.summary.isNotEmpty)
                  Text(plan.summary,
                      style: TextStyle(color: c.text, height: 1.4)),
                if (plan.focus.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(plan.focus,
                      style: TextStyle(color: c.accent, height: 1.4)),
                ],
              ],
            ),
          ),
        const SizedBox(height: 12),
        ...plan.suggestions.map(
          (suggestion) => _SuggestionCard(
            suggestion,
            onLog: () => onLog(suggestion),
          ),
        ),
        if (plan.caution.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(plan.caution,
              style: TextStyle(color: c.muted, fontSize: 11, height: 1.4)),
        ],
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final CoachSuggestion suggestion;
  final VoidCallback onLog;

  const _SuggestionCard(this.suggestion, {required this.onLog});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  suggestion.mealName,
                  style: TextStyle(
                    color: c.text,
                    fontFamily: 'Playfair Display',
                    fontSize: 18,
                  ),
                ),
              ),
              Text('${suggestion.calories.round()} kcal',
                  style: TextStyle(
                      color: c.accent,
                      fontFamily: 'DM Mono',
                      fontWeight: FontWeight.w800)),
            ],
          ),
          if (suggestion.timing.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(suggestion.timing.toUpperCase(),
                style: TextStyle(
                    color: c.muted, fontSize: 10, letterSpacing: 1.2)),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _MacroBadge('P', suggestion.protein, c.mint),
              _MacroBadge('C', suggestion.carbs, c.sky),
              _MacroBadge('F', suggestion.fat, c.peach),
              _MacroBadge('Fi', suggestion.fiber, c.plum),
            ],
          ),
          if (suggestion.why.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(suggestion.why,
                style: TextStyle(color: c.text, fontSize: 13, height: 1.35)),
          ],
          if (suggestion.ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            ...suggestion.ingredients.take(5).map((item) => Text('· $item',
                style: TextStyle(color: c.muted, fontSize: 12, height: 1.35))),
          ],
          if (suggestion.nutritionBreakdown.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Macro math',
                style: TextStyle(
                    color: c.accent, fontSize: 10, letterSpacing: 1.1)),
            const SizedBox(height: 5),
            ...suggestion.nutritionBreakdown.take(6).map(
                  (item) => Text(
                    '· $item',
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 12,
                      height: 1.35,
                      fontFamily: 'DM Mono',
                    ),
                  ),
                ),
          ],
          if (suggestion.steps.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(suggestion.steps.take(2).join(' '),
                style: TextStyle(
                    color: c.muted, fontSize: 12, fontStyle: FontStyle.italic)),
          ],
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: AppColors.darkBg,
                minimumSize: const Size.fromHeight(44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text(
                'Log this meal',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MacroBadge extends StatelessWidget {
  final String label;
  final double value;
  final Color color;

  const _MacroBadge(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          '$label ${value.round()}',
          textAlign: TextAlign.center,
          style: TextStyle(color: color, fontSize: 11, fontFamily: 'DM Mono'),
        ),
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;

  const _ErrorCard({required this.message});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.danger.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.danger),
      ),
      child: Text(message, style: TextStyle(color: c.danger, fontSize: 13)),
    );
  }
}

BoxDecoration _cardDecoration(AppColorsExtension c) => BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border),
    );
