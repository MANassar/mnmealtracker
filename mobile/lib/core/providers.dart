import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'models/meal.dart';
import 'models/weight_entry.dart';
import 'repositories/isar_repository.dart';
export 'repositories/isar_repository.dart' show ImportResult;
import 'repositories/settings_repository.dart';
import 'services/ai/ai_service.dart';

// ── Settings ───────────────────────────────────────────────────────────────

final settingsRepositoryProvider = Provider((_) => SettingsRepository());

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final repo = ref.read(settingsRepositoryProvider);
  return SettingsNotifier(repo);
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  final SettingsRepository _repo;

  SettingsNotifier(this._repo) : super(const AppSettings()) {
    _load();
  }

  Future<void> _load() async {
    state = await _repo.load();
  }

  Future<void> update(AppSettings settings) async {
    state = settings;
    await _repo.save(settings);
  }
}

// ── Meals ──────────────────────────────────────────────────────────────────

final mealsProvider = StateNotifierProvider<MealsNotifier, List<Meal>>(
    (ref) => MealsNotifier(ref));

class MealsNotifier extends StateNotifier<List<Meal>> {
  final Ref _ref;

  MealsNotifier(this._ref) : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await IsarRepository.instance.getAllMeals();
  }

  Future<void> refresh() => _load();

  Future<void> save(Meal meal) async {
    await IsarRepository.instance.saveMeal(meal);
    state = await IsarRepository.instance.getAllMeals();
  }

  Future<void> delete(int id) async {
    await IsarRepository.instance.deleteMeal(id);
    state = await IsarRepository.instance.getAllMeals();
  }

  Future<void> deleteAll() async {
    await IsarRepository.instance.deleteAllMeals();
    state = [];
  }

  Future<ImportResult> importJson(Map<String, dynamic> json) async {
    final result = await IsarRepository.instance.importFromJson(json);
    await refresh();
    await _ref.read(weightsProvider.notifier).refresh();
    return result;
  }
}

// ── Weights ────────────────────────────────────────────────────────────────

final weightsProvider =
    StateNotifierProvider<WeightsNotifier, List<WeightEntry>>(
        (_) => WeightsNotifier());

class WeightsNotifier extends StateNotifier<List<WeightEntry>> {
  WeightsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await IsarRepository.instance.getAllWeights();
  }

  Future<void> refresh() => _load();

  Future<void> save(WeightEntry entry) async {
    await IsarRepository.instance.saveWeight(entry);
    state = await IsarRepository.instance.getAllWeights();
  }

  Future<void> delete(int id) async {
    await IsarRepository.instance.deleteWeight(id);
    state = await IsarRepository.instance.getAllWeights();
  }
}

// ── AI ─────────────────────────────────────────────────────────────────────

final aiServiceProvider = Provider((_) => AiService());

// ── Global user values ─────────────────────────────────────────────────────

const double kgToLbs = 2.20462262;
const double lbsToKg = 0.45359237;

final userValuesProvider = Provider<UserValues>((ref) {
  final settings = ref.watch(settingsProvider);
  final weights = ref.watch(weightsProvider);
  return UserValues.from(settings: settings, weights: weights);
});

class MacroTargets {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double? fiber;

  const MacroTargets({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.fiber,
  });

  factory MacroTargets.fromSettings(AppSettings settings) => MacroTargets(
        calories: settings.goalCalories ?? 1800,
        protein: settings.goalProtein ?? 150,
        carbs: settings.goalCarbs ?? 180,
        fat: settings.goalFat ?? 60,
        fiber: settings.goalFiber,
      );

  Map<String, double> toRequiredMap() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
      };
}

class UserWeightValue {
  final double kg;
  final double display;
  final String unit;
  final String? date;
  final String source;

  const UserWeightValue({
    required this.kg,
    required this.display,
    required this.unit,
    required this.source,
    this.date,
  });

  String label({bool includeSource = false}) {
    final suffix = includeSource && source == 'macroProfile' ? ' setup' : '';
    return '${display.toStringAsFixed(1)} $unit$suffix';
  }

  Map<String, dynamic> toJson() => {
        'kg': kg,
        'display': display,
        'unit': unit,
        'date': date,
        'source': source,
      };
}

class UserValues {
  final AppSettings settings;
  final String weightUnit;
  final MacroTargets targets;
  final UserWeightValue? currentWeight;
  final double? goalWeightKg;
  final MacroProfile? macroProfile;
  final MacroRecommendation? macroRecommendation;

  const UserValues({
    required this.settings,
    required this.weightUnit,
    required this.targets,
    required this.currentWeight,
    required this.goalWeightKg,
    required this.macroProfile,
    required this.macroRecommendation,
  });

  factory UserValues.from({
    required AppSettings settings,
    required List<WeightEntry> weights,
  }) {
    final latestWeight = _latestWeight(weights);
    final profileWeight = settings.macroProfile?.weight;
    final profileWeightUnit =
        settings.macroProfile?.weightUnit ?? settings.weightUnit;
    final profileWeightKg = profileWeight == null
        ? null
        : profileWeightUnit == 'lbs'
            ? profileWeight * lbsToKg
            : profileWeight;
    return UserValues(
      settings: settings,
      weightUnit: settings.weightUnit,
      targets: MacroTargets.fromSettings(settings),
      currentWeight: latestWeight != null
          ? UserWeightValue(
              kg: latestWeight.weight,
              display: settings.weightUnit == 'lbs'
                  ? latestWeight.weight * kgToLbs
                  : latestWeight.weight,
              unit: settings.weightUnit,
              date: latestWeight.date,
              source: 'weightLog',
            )
          : profileWeightKg != null && profileWeightKg > 0
              ? UserWeightValue(
                  kg: profileWeightKg,
                  display: settings.weightUnit == 'lbs'
                      ? profileWeightKg * kgToLbs
                      : profileWeightKg,
                  unit: settings.weightUnit,
                  date: settings.macroProfile?.updatedAt,
                  source: 'macroProfile',
                )
              : null,
      goalWeightKg: settings.goalWeight,
      macroProfile: settings.macroProfile,
      macroRecommendation: settings.macroRecommendation,
    );
  }

  String get weightLabel =>
      currentWeight?.label(includeSource: true) ?? 'No weight yet';

  String get goalLabel => macroProfile?.goal ?? 'targets';

  MacroRecommendation? get recommendationForDisplay =>
      macroRecommendation ??
      (settings.goalCalories != null &&
              settings.goalProtein != null &&
              settings.goalCarbs != null &&
              settings.goalFat != null
          ? MacroRecommendation(
              calories: settings.goalCalories!,
              protein: settings.goalProtein!,
              carbs: settings.goalCarbs!,
              fat: settings.goalFat!,
              method: 'Using your saved daily targets.',
            )
          : null);

  Map<String, dynamic> toCoachUserJson() => {
        'weightUnit': weightUnit,
        'latestWeight': currentWeight?.toJson(),
        'goalWeightKg': goalWeightKg,
        'macroProfile': macroProfile?.toJson(),
        'macroRecommendation': macroRecommendation?.toJson(),
        'country': null,
        'fitness': {
          'available': false,
          'exercises': <String>[],
        },
      };
}

WeightEntry? _latestWeight(List<WeightEntry> weights) {
  if (weights.isEmpty) return null;
  final sorted = [...weights]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
  return sorted.first;
}

// ── Derived ────────────────────────────────────────────────────────────────

final todayMealsProvider = Provider<List<Meal>>((ref) {
  final meals = ref.watch(mealsProvider);
  final today = _todayStr();
  return meals.where((m) => m.date == today).toList();
});

String _todayStr() {
  final now = DateTime.now();
  final y = now.year.toString();
  final m = now.month.toString().padLeft(2, '0');
  final d = now.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
