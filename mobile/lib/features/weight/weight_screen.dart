import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/weight_entry.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';

class WeightScreen extends ConsumerStatefulWidget {
  const WeightScreen({super.key});

  @override
  ConsumerState<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends ConsumerState<WeightScreen> {
  bool _inputOpen = false;
  bool _goalOpen = false;
  final _weightCtrl = TextEditingController();
  final _goalCtrl = TextEditingController();

  @override
  void dispose() {
    _weightCtrl.dispose();
    _goalCtrl.dispose();
    super.dispose();
  }

  String _unit() => ref.read(settingsProvider).weightUnit;

  double _toKg(double v) =>
      _unit() == 'lbs' ? v * 0.45359237 : v;

  double _fromKg(double kg) =>
      _unit() == 'lbs' ? kg * 2.20462262 : kg;

  String _fmtWeight(double kg) {
    final v = _fromKg(kg);
    return '${v.toStringAsFixed(1)} ${_unit()}';
  }

  Future<void> _logWeight() async {
    final v = double.tryParse(_weightCtrl.text);
    if (v == null || v <= 0) return;
    final entry = WeightEntry()
      ..uuid = const Uuid().v4()
      ..date = _todayStr()
      ..timestamp = DateTime.now().millisecondsSinceEpoch
      ..weight = _toKg(v);
    await ref.read(weightsProvider.notifier).save(entry);
    _weightCtrl.clear();
    setState(() => _inputOpen = false);
  }

  Future<void> _setGoal() async {
    final v = double.tryParse(_goalCtrl.text);
    final settings = ref.read(settingsProvider);
    await ref
        .read(settingsProvider.notifier)
        .update(settings.copyWith(goalWeight: v != null ? _toKg(v) : null));
    _goalCtrl.clear();
    setState(() => _goalOpen = false);
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final weights = ref.watch(weightsProvider);
    final settings = ref.watch(settingsProvider);
    final c = context.appColors;
    final goalKg = settings.goalWeight;

    // Sorted ascending for chart
    final sorted = [...weights]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final latest = weights.isNotEmpty ? weights.first : null;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text('Weight', style: TextStyle(color: c.text)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined, color: c.muted),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Summary card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: c.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Current',
                              style: TextStyle(color: c.muted, fontSize: 12)),
                          Text(
                            latest != null
                                ? _fmtWeight(latest.weight)
                                : '—',
                            style: TextStyle(
                                color: c.text,
                                fontSize: 28,
                                fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const Spacer(),
                      if (goalKg != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('Goal',
                                style: TextStyle(color: c.muted, fontSize: 12)),
                            Text(
                              _fmtWeight(goalKg),
                              style: TextStyle(
                                  color: c.accent,
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600),
                            ),
                            if (latest != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                _delta(latest.weight, goalKg),
                                style: TextStyle(color: c.muted, fontSize: 12),
                              ),
                            ],
                          ],
                        ),
                    ],
                  ),

                  // Log weight controls
                  const SizedBox(height: 16),
                  if (_inputOpen)
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _weightCtrl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Weight (${_unit()})',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _logWeight(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: _logWeight, child: const Text('Save')),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () =>
                            setState(() => _inputOpen = false),
                        child: const Text('Cancel'),
                      ),
                    ])
                  else
                    Center(
                      child: ElevatedButton.icon(
                        onPressed: () => setState(() => _inputOpen = true),
                        icon: const Icon(Icons.add),
                        label: const Text('Log weight'),
                      ),
                    ),

                  // Set goal
                  if (_goalOpen) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: TextField(
                          controller: _goalCtrl,
                          autofocus: true,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
                          ],
                          decoration: InputDecoration(
                            labelText: 'Goal weight (${_unit()})',
                            isDense: true,
                          ),
                          onSubmitted: (_) => _setGoal(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(onPressed: _setGoal, child: const Text('Set')),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() => _goalOpen = false),
                        child: const Text('Cancel'),
                      ),
                    ]),
                  ] else
                    Center(
                      child: TextButton.icon(
                        onPressed: () => setState(() => _goalOpen = true),
                        icon: Icon(Icons.flag_outlined, size: 16, color: c.muted),
                        label: Text(
                            goalKg != null ? 'Change goal' : 'Set goal',
                            style: TextStyle(color: c.muted)),
                      ),
                    ),
                ],
              ),
            ),

            // Chart
            if (sorted.length >= 2) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Progress',
                        style: TextStyle(
                            color: c.text, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 160,
                      child: _WeightChart(
                        entries: sorted,
                        goalKg: goalKg,
                        fromKg: _fromKg,
                        color: c.accent,
                        goalColor: c.mint,
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // History list
            if (weights.isNotEmpty) ...[
              const SizedBox(height: 20),
              Text('History',
                  style: TextStyle(
                      color: c.text,
                      fontWeight: FontWeight.w600,
                      fontSize: 15)),
              const SizedBox(height: 10),
              ...weights.map((e) => _WeightEntryTile(
                    entry: e,
                    displayWeight: _fmtWeight(e.weight),
                    onDelete: () => _confirmDelete(context, ref, e),
                  )),
            ],

            const SizedBox(height: 80),
          ],
        ),
      ),
    );
  }

  String _delta(double current, double goal) {
    final diff = _fromKg((current - goal).abs());
    final dir = current > goal ? 'to lose' : 'to gain';
    return '${diff.toStringAsFixed(1)} ${_unit()} $dir';
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, WeightEntry entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text('Remove this weight log?'),
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
    if (ok == true) await ref.read(weightsProvider.notifier).delete(entry.id);
  }
}

class _WeightEntryTile extends StatelessWidget {
  final WeightEntry entry;
  final String displayWeight;
  final VoidCallback onDelete;

  const _WeightEntryTile({
    required this.entry,
    required this.displayWeight,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final dt = DateTime.fromMillisecondsSinceEpoch(entry.timestamp);
    final dateStr =
        '${dt.day}/${dt.month}/${dt.year}  ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Text(displayWeight,
              style: TextStyle(
                  color: c.text,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          const Spacer(),
          Text(dateStr, style: TextStyle(color: c.muted, fontSize: 12)),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: onDelete,
            child: Icon(Icons.delete_outline, size: 18, color: c.danger),
          ),
        ],
      ),
    );
  }
}

class _WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double? goalKg;
  final double Function(double) fromKg;
  final Color color;
  final Color goalColor;

  const _WeightChart({
    required this.entries,
    required this.fromKg,
    required this.color,
    required this.goalColor,
    this.goalKg,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final spots = entries
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), fromKg(e.value.weight)))
        .toList();

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final yPad = ((maxY - minY) * 0.15).clamp(0.5, 5.0);

    return LineChart(
      LineChartData(
        minY: minY - yPad,
        maxY: maxY + yPad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: c.border, strokeWidth: 1),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: TextStyle(color: c.muted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        extraLinesData: goalKg != null
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: fromKg(goalKg!),
                  color: goalColor.withOpacity(0.6),
                  strokeWidth: 1.5,
                  dashArray: [6, 4],
                ),
              ])
            : null,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: color,
            barWidth: 2.5,
            dotData: FlDotData(
              show: true,
              getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                radius: 3,
                color: color,
                strokeWidth: 0,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: color.withOpacity(0.08),
            ),
          ),
        ],
      ),
    );
  }
}
