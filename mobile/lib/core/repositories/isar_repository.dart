import 'dart:convert';
import 'dart:io';

import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../models/meal.dart';
import '../models/weight_entry.dart';

class ImportResult {
  final int meals;
  final int weights;
  const ImportResult({required this.meals, required this.weights});
}

class IsarRepository {
  IsarRepository._();
  static IsarRepository? _instance;
  static IsarRepository get instance => _instance!;

  late final Isar _isar;

  static Future<void> init() async {
    if (_instance != null) return;
    _instance = IsarRepository._();
    final dir = await getApplicationDocumentsDirectory();
    _instance!._isar = await Isar.open(
      [MealSchema, WeightEntrySchema],
      directory: dir.path,
    );
  }

  // ── Meals ──────────────────────────────────────────────────────────────────

  Future<List<Meal>> getMealsForDate(String date) =>
      _isar.meals.filter().dateEqualTo(date).sortByTimestampDesc().findAll();

  Future<List<Meal>> getAllMeals() =>
      _isar.meals.where().sortByDateDesc().thenByTimestampDesc().findAll();

  Future<void> saveMeal(Meal meal) async {
    if (meal.uuid.isEmpty) meal.uuid = const Uuid().v4();
    await _isar.writeTxn(() => _isar.meals.put(meal));
  }

  Future<void> deleteMeal(Id id) async {
    final meal = await _isar.meals.get(id);
    if (meal?.imagePath != null) {
      final f = File(meal!.imagePath!);
      if (await f.exists()) await f.delete();
    }
    await _isar.writeTxn(() => _isar.meals.delete(id));
  }

  Future<void> deleteAllMeals() async {
    final meals = await _isar.meals.where().findAll();
    for (final m in meals) {
      if (m.imagePath != null) {
        final f = File(m.imagePath!);
        if (await f.exists()) await f.delete();
      }
    }
    await _isar.writeTxn(() => _isar.meals.clear());
  }

  // ── Weights ────────────────────────────────────────────────────────────────

  Future<List<WeightEntry>> getAllWeights() =>
      _isar.weightEntrys.where().sortByDateDesc().thenByTimestampDesc().findAll();

  Future<void> saveWeight(WeightEntry entry) async {
    if (entry.uuid.isEmpty) entry.uuid = const Uuid().v4();
    await _isar.writeTxn(() => _isar.weightEntrys.put(entry));
  }

  Future<void> deleteWeight(Id id) =>
      _isar.writeTxn(() => _isar.weightEntrys.delete(id));

  // ── Export / Import ────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> exportToJson() async {
    final meals = await getAllMeals();
    final weights = await getAllWeights();
    return {
      'exportedAt': DateTime.now().toIso8601String(),
      'meals': meals.map(_mealToJson).toList(),
      'weights': weights.map(_weightToJson).toList(),
    };
  }

  Future<ImportResult> importFromJson(
      Map<String, dynamic> json) async {
    final rawMeals = (json['meals'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final rawWeights =
        (json['weights'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final existing = await getAllMeals();
    final existingUuids = {for (final m in existing) m.uuid};

    int mealCount = 0;
    int weightCount = 0;

    await _isar.writeTxn(() async {
      for (final raw in rawMeals) {
        final meal = _mealFromJson(raw);
        if (!existingUuids.contains(meal.uuid)) {
          await _isar.meals.put(meal);
          mealCount++;
        }
      }
      for (final raw in rawWeights) {
        final entry = _weightFromJson(raw);
        await _isar.weightEntrys.put(entry);
        weightCount++;
      }
    });

    return ImportResult(meals: mealCount, weights: weightCount);
  }

  // ── JSON helpers ───────────────────────────────────────────────────────────

  Map<String, dynamic> _mealToJson(Meal m) => {
        'id': m.uuid,
        'date': m.date,
        'timestamp': m.timestamp,
        'mealName': m.mealName,
        'calories': m.calories,
        'protein': m.protein,
        'carbs': m.carbs,
        'fat': m.fat,
        'fiber': m.fiber,
        if (m.provider != null) 'provider': m.provider,
        if (m.confidence != null) 'confidence': m.confidence,
        if (m.portionNote != null) 'portionNote': m.portionNote,
        if (m.description != null) 'description': m.description,
        if (m.ingredients != null) 'ingredients': jsonDecode(m.ingredients!),
        // photos are excluded from export (too large); same as PWA
      };

  Meal _mealFromJson(Map<String, dynamic> json) {
    final meal = Meal()
      ..uuid = (json['id'] as String?) ?? const Uuid().v4()
      ..date = json['date'] as String
      ..timestamp = (json['timestamp'] as num).toInt()
      ..mealName = json['mealName'] as String? ?? 'Unknown meal'
      ..calories = (json['calories'] as num?)?.toDouble() ?? 0
      ..protein = (json['protein'] as num?)?.toDouble() ?? 0
      ..carbs = (json['carbs'] as num?)?.toDouble() ?? 0
      ..fat = (json['fat'] as num?)?.toDouble() ?? 0
      ..fiber = (json['fiber'] as num?)?.toDouble() ?? 0
      ..provider = json['provider'] as String?
      ..confidence = json['confidence'] as String?
      ..portionNote = json['portionNote'] as String?
      ..description = json['description'] as String?;

    final ing = json['ingredients'];
    if (ing is List) meal.ingredients = jsonEncode(ing);

    return meal;
  }

  Map<String, dynamic> _weightToJson(WeightEntry e) => {
        'id': e.uuid,
        'date': e.date,
        'timestamp': e.timestamp,
        'weight': e.weight,
      };

  WeightEntry _weightFromJson(Map<String, dynamic> json) => WeightEntry()
    ..uuid = (json['id'] as String?) ?? const Uuid().v4()
    ..date = json['date'] as String
    ..timestamp = (json['timestamp'] as num).toInt()
    ..weight = (json['weight'] as num).toDouble();
}
