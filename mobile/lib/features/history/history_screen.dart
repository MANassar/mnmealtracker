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
import '../../core/providers.dart';
import '../../core/repositories/isar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/meal_card.dart';

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allMeals = ref.watch(mealsProvider);
    final c = context.appColors;

    final grouped = <String, List<Meal>>{};
    for (final m in allMeals) {
      grouped.putIfAbsent(m.date, () => []).add(m);
    }
    final dates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text('History', style: TextStyle(color: c.text)),
        actions: [
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: c.muted),
            onSelected: (v) => _onMenu(context, ref, v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'export', child: Text('Export backup')),
              PopupMenuItem(value: 'import', child: Text('Import backup')),
              PopupMenuItem(value: 'clear', child: Text('Clear all meals')),
            ],
          ),
        ],
      ),
      body: allMeals.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 48, color: c.muted.withOpacity(0.4)),
                  const SizedBox(height: 12),
                  Text('No meal history yet', style: TextStyle(color: c.muted)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: dates.length,
              itemBuilder: (context, i) {
                final date = dates[i];
                final meals = grouped[date]!;
                final totalCal =
                    meals.fold<double>(0.0, (s, m) => s + m.calories);

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 4),
                      child: Row(
                        children: [
                          Text(
                            _fmtDate(date),
                            style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w600,
                                fontSize: 14),
                          ),
                          const Spacer(),
                          Text('${totalCal.toInt()} kcal',
                              style: TextStyle(color: c.muted, fontSize: 13)),
                        ],
                      ),
                    ),
                    ...meals.map((meal) => MealCard(
                          meal: meal,
                          onEdit: () => context.push('/add', extra: {
                            'editingMeal': meal,
                            'returnPath': '/history',
                          }),
                          onDelete: () => _confirmDelete(context, ref, meal),
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
    );
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
      builder: (_) => AlertDialog(
        title: const Text('Delete meal?'),
        content: Text('Remove "${meal.mealName}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) await ref.read(mealsProvider.notifier).delete(meal.id);
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
      await Share.shareXFiles([XFile(file.path)],
          subject: 'Meal Tracker backup');
    } catch (e) {
      {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    try {
      final picked = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (picked == null || picked.files.single.path == null) return;

      final raw = await File(picked.files.single.path!).readAsString();
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final result = await ref.read(mealsProvider.notifier).importJson(json);

      {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Imported ${result.meals} meals, ${result.weights} weights'),
        ));
      }
    } catch (e) {
      {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Import failed: $e')));
      }
    }
  }

  Future<void> _clear(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear all meals?'),
        content: const Text(
            'This will permanently delete all logged meals. Export a backup first.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Clear all')),
        ],
      ),
    );
    if (ok == true) await ref.read(mealsProvider.notifier).deleteAll();
  }
}
