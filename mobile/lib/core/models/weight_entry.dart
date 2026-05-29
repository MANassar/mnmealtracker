import 'package:isar/isar.dart';

part 'weight_entry.g.dart';

@collection
class WeightEntry {
  Id id = Isar.autoIncrement;

  late String uuid;
  late String date; // yyyy-MM-dd
  late int timestamp; // ms since epoch
  late double weight; // always stored in kg internally
}
