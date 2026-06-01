import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

import '../../core/models/meal.dart';
import '../../core/models/weight_entry.dart';
import '../../core/providers.dart';
import '../../core/repositories/isar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/meal_card.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _filter = 'all';

  @override
  Widget build(BuildContext context) {
    final allMeals = ref.watch(mealsProvider);
    final weights = ref.watch(weightsProvider);
    final settings = ref.watch(settingsProvider);
    final c = context.appColors;

    final grouped = <String, List<Meal>>{};
    for (final m in allMeals) {
      grouped.putIfAbsent(m.date, () => []).add(m);
    }
    final dates = _datesFor(grouped, weights);

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'History',
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Playfair Display',
                            fontSize: 24,
                          ),
                        ),
                      ),
                      PopupMenuButton<String>(
                        icon: Icon(Icons.more_vert, color: c.muted),
                        color: c.card,
                        onSelected: (v) => _onMenu(context, ref, v),
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'export',
                            child: Text('Export backup',
                                style: TextStyle(color: c.text)),
                          ),
                          PopupMenuItem(
                            value: 'import',
                            child: Text('Import backup',
                                style: TextStyle(color: c.text)),
                          ),
                          PopupMenuItem(
                            value: 'clear',
                            child: Text('Clear all meals',
                                style: TextStyle(color: c.text)),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _FilterPill(
                        label: 'All',
                        active: _filter == 'all',
                        onTap: () => setState(() => _filter = 'all'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Meals',
                        active: _filter == 'meals',
                        onTap: () => setState(() => _filter = 'meals'),
                      ),
                      const SizedBox(width: 8),
                      _FilterPill(
                        label: 'Weight',
                        active: _filter == 'weight',
                        onTap: () => setState(() => _filter = 'weight'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: allMeals.isEmpty && weights.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.history,
                          size: 48,
                          color: c.muted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 12),
                        Text('Meals will appear here after you log them.',
                            style: TextStyle(color: c.muted)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: dates.length,
                    itemBuilder: (context, i) {
                      final date = dates[i];
                      final showMeals = _filter == 'all' || _filter == 'meals';
                      final showWeight =
                          _filter == 'all' || _filter == 'weight';
                      final meals =
                          showMeals ? (grouped[date] ?? []) : <Meal>[];
                      final dayWeight = showWeight
                          ? _firstWeightForDate(weights, date)
                          : null;
                      if (meals.isEmpty && dayWeight == null) {
                        return const SizedBox.shrink();
                      }
                      final totalCal =
                          meals.fold<double>(0.0, (s, m) => s + m.calories);
                      final totalP =
                          meals.fold<double>(0.0, (s, m) => s + m.protein);
                      final totalC =
                          meals.fold<double>(0.0, (s, m) => s + m.carbs);
                      final totalF =
                          meals.fold<double>(0.0, (s, m) => s + m.fat);
                      final targetCalories = settings.goalCalories ?? 1800;
                      final over = totalCal > targetCalories;
                      final sortedMeals = [...meals]
                        ..sort((a, b) => b.timestamp.compareTo(a.timestamp));

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8, top: 4),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _fmtDate(date),
                                        style: TextStyle(
                                          color: c.text,
                                          fontFamily: 'Playfair Display',
                                          fontSize: 17,
                                        ),
                                      ),
                                      if (meals.isNotEmpty)
                                        Text(
                                          '${meals.length} Meal${meals.length == 1 ? '' : 's'}',
                                          style: TextStyle(
                                            color: c.muted,
                                            fontSize: 10,
                                            letterSpacing: 1,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                                if (meals.isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      Text(
                                        '${totalCal.round()} kcal',
                                        style: TextStyle(
                                          color: over ? c.danger : c.mint,
                                          fontFamily: 'DM Mono',
                                          fontWeight: FontWeight.w700,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        '${totalP.toStringAsFixed(0)}P · ${totalC.toStringAsFixed(0)}C · ${totalF.toStringAsFixed(0)}F',
                                        style: TextStyle(
                                          color: c.muted,
                                          fontFamily: 'DM Mono',
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (meals.isNotEmpty) ...[
                            ClipRRect(
                              borderRadius: BorderRadius.circular(1),
                              child: LinearProgressIndicator(
                                value:
                                    (totalCal / targetCalories).clamp(0.0, 1.0),
                                minHeight: 2,
                                backgroundColor: c.card,
                                valueColor: AlwaysStoppedAnimation(
                                  over ? c.danger : c.accent,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                          ],
                          if (dayWeight != null)
                            _HistoryWeightCard(
                              entry: dayWeight,
                              unit: settings.weightUnit,
                              onDelete: () =>
                                  _confirmDeleteWeight(context, ref, dayWeight),
                            ),
                          ...sortedMeals.map((meal) => MealCard(
                                meal: meal,
                                onEdit: () => context.push('/add', extra: {
                                  'editingMeal': meal,
                                  'returnPath': '/history',
                                }),
                                onDelete: () =>
                                    _confirmDelete(context, ref, meal),
                                onLogAgain: () => context.push('/add', extra: {
                                  'repeatMeal': meal,
                                  'returnPath': '/today',
                                }),
                              )),
                          const SizedBox(height: 8),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<String> _datesFor(
    Map<String, List<Meal>> grouped,
    List<WeightEntry> weights,
  ) {
    final showMeals = _filter == 'all' || _filter == 'meals';
    final showWeight = _filter == 'all' || _filter == 'weight';
    final dates = <String>{
      if (showMeals) ...grouped.keys,
      if (showWeight) ...weights.map((w) => w.date),
    }.toList()
      ..sort((a, b) => b.compareTo(a));
    return dates;
  }

  WeightEntry? _firstWeightForDate(List<WeightEntry> weights, String date) {
    for (final entry in weights) {
      if (entry.date == date) return entry;
    }
    return null;
  }

  String _fmtDate(String date) {
    try {
      final dt = DateTime.parse('${date}T12:00:00');
      return DateFormat('EEE, d MMM').format(dt);
    } catch (_) {
      return date;
    }
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Meal meal) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${meal.mealName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(mealsProvider.notifier).delete(meal.id);
  }

  Future<void> _confirmDeleteWeight(
      BuildContext context, WidgetRef ref, WeightEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('Remove this weight log?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(weightsProvider.notifier).delete(entry.id);
  }

  Future<void> _onMenu(
      BuildContext context, WidgetRef ref, String action) async {
    switch (action) {
      case 'export':
        await _export(context, ref);
        break;
      case 'import':
        await _import(context, ref);
        break;
      case 'clear':
        await _clear(context, ref);
        break;
    }
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final data = await IsarRepository.instance.exportToJson();
      final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final now = DateTime.now();
      final fname =
          'meal-tracker-export-${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}.json';
      final file = File('${dir.path}/$fname');
      await file.writeAsString(jsonStr);
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          subject: 'Meal Tracker backup',
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null || picked.files.single.path == null) return;

      final raw = await File(picked.files.single.path!).readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final result = await ref.read(mealsProvider.notifier).importJson(json);

      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text('Imported ${result.meals} meals, ${result.weights} weights'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear all meals?'),
        content: const Text(
            'This will permanently delete all logged meals. Export a backup first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (ok == true) await ref.read(mealsProvider.notifier).deleteAll();
  }
}

class _FilterPill extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _FilterPill({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color:
                active ? c.accent.withValues(alpha: 0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Text(
            label.toUpperCase(),
            style: TextStyle(
              color: active ? c.accent : c.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
        ),
      ),
    );
  }
}

class _HistoryWeightCard extends StatelessWidget {
  final WeightEntry entry;
  final String unit;
  final VoidCallback onDelete;

  const _HistoryWeightCard({
    required this.entry,
    required this.unit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final value = unit == 'lbs' ? entry.weight * 2.20462262 : entry.weight;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Text('⚖', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    text: value.toStringAsFixed(1),
                    children: [
                      TextSpan(
                        text: ' $unit',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 12,
                          fontFamily: 'DM Sans',
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  style: TextStyle(
                    color: c.mint,
                    fontFamily: 'DM Mono',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _fmtTime(entry.timestamp),
                  style: TextStyle(color: c.muted, fontSize: 10),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 34,
            child: TextButton(
              onPressed: onDelete,
              style: TextButton.styleFrom(
                foregroundColor: c.muted,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(color: c.border),
                ),
                textStyle: const TextStyle(fontSize: 11),
              ),
              child: const Text('Delete'),
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
