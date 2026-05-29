import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/app_settings.dart';
import 'models/meal.dart';
import 'models/weight_entry.dart';
import 'repositories/isar_repository.dart';
export 'repositories/isar_repository.dart' show ImportResult;
import 'repositories/settings_repository.dart';
import 'services/ai/ai_service.dart';

// ── Settings ───────────────────────────────────────────────────────────────

final settingsRepositoryProvider =
    Provider((_) => SettingsRepository());

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

final mealsProvider =
    StateNotifierProvider<MealsNotifier, List<Meal>>((_) => MealsNotifier());

class MealsNotifier extends StateNotifier<List<Meal>> {
  MealsNotifier() : super([]) {
    _load();
  }

  Future<void> _load() async {
    state = await IsarRepository.instance.getAllMeals();
  }

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
    state = await IsarRepository.instance.getAllMeals();
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
