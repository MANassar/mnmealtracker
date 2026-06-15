import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/app_settings.dart';
import '../../core/models/meal.dart';
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
    final userValues = ref.watch(userValuesProvider);
    final meals = ref.watch(mealsProvider);
    final todayMeals = ref.watch(todayMealsProvider);
    final c = context.appColors;
    final totals = _totals(todayMeals);
    final targets = userValues.targets.toRequiredMap();

    final remaining = {
      'calories': (targets['calories'] ?? 0) - (totals['calories'] ?? 0),
      'protein': (targets['protein'] ?? 0) - (totals['protein'] ?? 0),
      'carbs': (targets['carbs'] ?? 0) - (totals['carbs'] ?? 0),
      'fat': (targets['fat'] ?? 0) - (totals['fat'] ?? 0),
    };

    return SizedBox.expand(
        child: Column(
      children: [
        GlassAppBar(
          centerTitle: false,
          preferredSize: const Size.fromHeight(60),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Coach',
                style: TextStyle(
                  color: c.text,
                  fontFamily: 'Playfair Display',
                  fontSize: 24,
                ),
              ),
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
          actions: [
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: Icon(Icons.settings, color: c.muted),
            ),
          ],
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
            children: [
              _DailyFitCard(totals: totals, targets: targets),
              const SizedBox(height: 12),
              _ContextCard(
                mealCount: meals.length,
                displayWeight: userValues.weightLabel,
                goalLabel: userValues.goalLabel,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _loading
                    ? null
                    : () => _getCoachPlan(settings, meals, userValues),
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
                  afterIntro: _FamiliarMealsRow(
                    meals: meals,
                    targets: targets,
                    remaining: remaining,
                    onLog: _logHistoryMeal,
                  ),
                ),
                const SizedBox(height: 2),
                OutlinedButton(
                  onPressed: _loading
                      ? null
                      : () => _getCoachPlan(
                            settings,
                            meals,
                            userValues,
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
    ));
  }

  Future<void> _getCoachPlan(
      AppSettings settings, List<Meal> meals, UserValues userValues,
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
              userValues,
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
      AppSettings settings, List<Meal> meals, UserValues userValues,
      {List<CoachSuggestion>? existingSuggestions}) {
    final now = DateTime.now();
    final today = _todayStr(now);
    final todayMeals = meals.where((m) => m.date == today).toList();
    final recentMeals = [...meals]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final targets = userValues.targets.toRequiredMap();
    final consumed = _totals(todayMeals);

    final remainingToday = {
      'calories': targets['calories']! - consumed['calories']!,
      'protein': targets['protein']! - consumed['protein']!,
      'carbs': targets['carbs']! - consumed['carbs']!,
      'fat': targets['fat']! - consumed['fat']!,
    };
    final mealType = _mealSlot(now.hour);
    final currentMealMaxCalories = _currentMealMaxCalories(
      hour: now.hour,
      targetCalories: targets['calories']!,
      remainingCalories: remainingToday['calories']!,
    );

    return {
      'generatedAt': now.toIso8601String(),
      'localTime': {
        'hour': now.hour,
        'weekday': now.weekday,
        'label': _timeLabel(now),
        'mealType': mealType,
      },
      'targets': targets,
      'consumedToday': consumed,
      'remainingToday': remainingToday,
      'currentMealGuidance': {
        'mealType': mealType,
        'maxCalories': currentMealMaxCalories,
        'note':
            'Use this as the upper bound for the next meal so suggestions do not front-load the remaining day.',
      },
      'user': userValues.toCoachUserJson(),
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

  Future<void> _logHistoryMeal(Meal meal) async {
    final now = DateTime.now();
    final newMeal = Meal()
      ..uuid = const Uuid().v4()
      ..date = _todayStr(now)
      ..timestamp = now.millisecondsSinceEpoch
      ..mealName = meal.mealName
      ..calories = meal.calories
      ..protein = meal.protein
      ..carbs = meal.carbs
      ..fat = meal.fat
      ..fiber = meal.fiber
      ..provider = meal.provider
      ..confidence = meal.confidence
      ..portionNote = meal.portionNote
      ..description = meal.description
      ..ingredients = meal.ingredients;
    await ref.read(mealsProvider.notifier).save(newMeal);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Logged ${meal.mealName}')),
    );
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

  Map<String, dynamic> _mealContext(Meal meal) {
    final mealTime = DateTime.fromMillisecondsSinceEpoch(meal.timestamp);
    return {
      'date': meal.date,
      'timestamp': mealTime.toIso8601String(),
      'mealType': _mealSlot(mealTime.hour),
      'mealName': meal.mealName,
      'calories': meal.calories,
      'protein': meal.protein,
      'carbs': meal.carbs,
      'fat': meal.fat,
      'fiber': meal.fiber,
      'description': _shortText(meal.description, 120),
      'ingredients': _ingredients(meal.ingredients).take(5).toList(),
    };
  }

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

  Map<String, double> _totals(List<Meal> meals) => {
        'calories': meals.fold<double>(0, (s, m) => s + m.calories),
        'protein': meals.fold<double>(0, (s, m) => s + m.protein),
        'carbs': meals.fold<double>(0, (s, m) => s + m.carbs),
        'fat': meals.fold<double>(0, (s, m) => s + m.fat),
      };

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

  String _mealSlot(int hour) => hour < 11
      ? 'breakfast'
      : hour < 15
          ? 'lunch'
          : hour < 18
              ? 'snack'
              : 'dinner';

  static double _currentMealMaxCalories({
    required int hour,
    required double targetCalories,
    required double remainingCalories,
  }) {
    if (remainingCalories <= 0) return 0;
    final slotShare = hour < 11
        ? 0.30
        : hour < 15
            ? 0.40
            : hour < 18
                ? 0.20
                : 0.70;
    final remainingShare = hour < 18 ? 0.65 : 1.05;
    final slotCap = targetCalories * slotShare;
    final remainingCap = remainingCalories * remainingShare;
    return slotCap < remainingCap ? slotCap : remainingCap;
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
  final String displayWeight;
  final String goalLabel;

  const _ContextCard({
    required this.mealCount,
    required this.displayWeight,
    required this.goalLabel,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: _cardDecoration(c),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _Chip('Meals', '$mealCount logged'),
          _Chip('Weight', displayWeight),
          _Chip('Goal', goalLabel),
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
  final Widget? afterIntro;

  const _PlanCard({required this.plan, required this.onLog, this.afterIntro});

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
        if (afterIntro != null) ...[
          const SizedBox(height: 12),
          afterIntro!,
        ],
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

class _FamiliarMealsRow extends StatelessWidget {
  final List<Meal> meals;
  final Map<String, double> targets;
  final Map<String, double> remaining;
  final ValueChanged<Meal> onLog;

  const _FamiliarMealsRow({
    required this.meals,
    required this.targets,
    required this.remaining,
    required this.onLog,
  });

  static int _timeBucket(int hour) {
    if (hour < 11) return 0; // morning
    if (hour < 15) return 1; // midday
    if (hour < 18) return 2; // afternoon
    return 3; // evening
  }

  static String _bucketName(int bucket) {
    switch (bucket) {
      case 0:
        return 'breakfast';
      case 1:
        return 'lunch';
      case 2:
        return 'snack';
      default:
        return 'dinner';
    }
  }

  List<MapEntry<Meal, String>> _candidatesWithSlots() {
    final remCals = remaining['calories'] ?? 0;
    final remP = remaining['protein'] ?? 0;
    final remC = remaining['carbs'] ?? 0;
    final remF = remaining['fat'] ?? 0;

    if (remCals <= 0) return [];

    final now = DateTime.now();
    final currentBucket = _timeBucket(now.hour);
    final maxCalories = _CoachScreenState._currentMealMaxCalories(
      hour: now.hour,
      targetCalories: targets['calories'] ?? remCals,
      remainingCalories: remCals,
    );

    final freq = <String, int>{};
    final bucketCounts = <String, Map<int, int>>{};
    final latest = <String, Meal>{};

    final sorted = [...meals]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

    for (final meal in sorted) {
      final key = meal.mealName.toLowerCase().trim();
      if (key.isEmpty) continue;
      freq[key] = (freq[key] ?? 0) + 1;
      final bucket = _timeBucket(
        DateTime.fromMillisecondsSinceEpoch(meal.timestamp).hour,
      );
      (bucketCounts.putIfAbsent(key, () => {}))[bucket] =
          ((bucketCounts[key]![bucket]) ?? 0) + 1;
      if (bucket == currentBucket) latest.putIfAbsent(key, () => meal);
    }

    final filtered = latest.values.where((m) {
      final key = m.mealName.toLowerCase().trim();
      final timeLogs = bucketCounts[key]?[currentBucket] ?? 0;
      if (timeLogs == 0) return false;
      if (m.calories <= 0) return false;
      if (m.calories > maxCalories) return false;
      // Reject if any macro wildly overshoots what's left (50% tolerance).
      // Only applies when there's a meaningful amount still remaining.
      if (remP > 10 && m.protein > remP * 1.5) return false;
      if (remC > 10 && m.carbs > remC * 1.5) return false;
      if (remF > 5 && m.fat > remF * 1.5) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final as_ = _candidateScore(
          a,
          freq,
          bucketCounts,
          currentBucket,
          remP,
          remC,
          remF,
        );
        final bs_ = _candidateScore(
          b,
          freq,
          bucketCounts,
          currentBucket,
          remP,
          remC,
          remF,
        );
        return bs_.compareTo(as_);
      });

    return filtered.map((m) {
      final key = m.mealName.toLowerCase().trim();
      final bMap = bucketCounts[key] ?? {};
      final typicalBucket = bMap.isEmpty
          ? currentBucket
          : bMap.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      return MapEntry(m, _bucketName(typicalBucket));
    }).toList();
  }

  static double _candidateScore(
    Meal meal,
    Map<String, int> freq,
    Map<String, Map<int, int>> bucketCounts,
    int currentBucket,
    double remP,
    double remC,
    double remF,
  ) {
    final key = meal.mealName.toLowerCase().trim();
    double score = 0;

    // Frequency bonus (up to 10 pts).
    score += (freq[key] ?? 0).clamp(0, 10).toDouble();

    // Time-of-day match: fraction of historical logs in the current bucket
    // (up to 15 pts). Meals never eaten at this time of day score 0 here.
    final bMap = bucketCounts[key] ?? {};
    final totalLogs = freq[key] ?? 1;
    final timeLogs = bMap[currentBucket] ?? 0;
    score += (timeLogs / totalLogs) * 15.0;

    // Macro fit: reward meals that proportionally fill remaining targets.
    if (remP > 0) score += (meal.protein / remP).clamp(0.0, 1.0) * 10.0;
    if (remC > 0) score += (meal.carbs / remC).clamp(0.0, 1.0) * 5.0;
    if (remF > 0) score += (meal.fat / remF).clamp(0.0, 1.0) * 5.0;

    return score;
  }

  @override
  Widget build(BuildContext context) {
    final candidates = _candidatesWithSlots();
    if (candidates.isEmpty) return const SizedBox.shrink();

    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FROM YOUR HISTORY',
          style: TextStyle(color: c.muted, fontSize: 10, letterSpacing: 1.4),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 165,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: candidates.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (_, i) => _FamiliarCard(
              candidates[i].key,
              typicalSlot: candidates[i].value,
              onLog: () => onLog(candidates[i].key),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _FamiliarCard extends StatelessWidget {
  final Meal meal;
  final String typicalSlot;
  final VoidCallback onLog;

  const _FamiliarCard(this.meal,
      {required this.typicalSlot, required this.onLog});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final now = DateTime.now();
    final currentHour = now.hour;
    final currentSlot = currentHour < 11
        ? 'breakfast'
        : currentHour < 15
            ? 'lunch'
            : currentHour < 18
                ? 'snack'
                : 'dinner';
    final isCurrentTime = typicalSlot == currentSlot;

    return Container(
      width: 165,
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meal.mealName,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Playfair Display',
              fontSize: 13,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            typicalSlot.toUpperCase(),
            style: TextStyle(
              color: isCurrentTime ? c.accent : c.muted,
              fontSize: 9,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${meal.calories.round()} kcal',
            style: TextStyle(
              color: c.accent,
              fontFamily: 'DM Mono',
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: [
              Text('P${meal.protein.round()}',
                  style: TextStyle(
                      color: c.mint, fontSize: 10, fontFamily: 'DM Mono')),
              const SizedBox(width: 6),
              Text('C${meal.carbs.round()}',
                  style: TextStyle(
                      color: c.sky, fontSize: 10, fontFamily: 'DM Mono')),
              const SizedBox(width: 6),
              Text('F${meal.fat.round()}',
                  style: TextStyle(
                      color: c.peach, fontSize: 10, fontFamily: 'DM Mono')),
            ],
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onLog,
              style: ElevatedButton.styleFrom(
                backgroundColor: c.accent,
                foregroundColor: AppColors.darkBg,
                minimumSize: const Size.fromHeight(34),
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Log',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

BoxDecoration _cardDecoration(AppColorsExtension c) => BoxDecoration(
      color: c.card,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: c.border),
    );
