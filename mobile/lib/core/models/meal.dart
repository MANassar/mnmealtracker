import 'package:isar/isar.dart';

part 'meal.g.dart';

@collection
class Meal {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String date; // yyyy-MM-dd
  late int timestamp; // ms since epoch
  late String mealName;
  late double calories;
  late double protein;
  late double carbs;
  late double fat;
  late double fiber;

  @Index()
  String? provider; // anthropic | openai | server | manual

  String? confidence; // high | medium | low
  String? portionNote;
  String? description;
  String? imagePath; // local file path, null if no photo
  String? ingredients; // JSON-encoded list

  bool get isManual => provider == null || provider == 'manual';
}
