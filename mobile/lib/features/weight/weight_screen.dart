import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/weight_entry.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pwa_chrome.dart';

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

  String _unit() => ref.read(userValuesProvider).weightUnit;

  double _toKg(double v) => _unit() == 'lbs' ? v * lbsToKg : v;

  double _fromKg(double kg) => _unit() == 'lbs' ? kg * kgToLbs : kg;

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
    final userValues = ref.watch(userValuesProvider);
    final c = context.appColors;
    final goalKg = userValues.goalWeightKg;

    // Sorted ascending for chart
    final sorted = [...weights]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final todayMatches = weights.where((w) => w.date == _todayStr()).toList();
    final todayWeight = todayMatches.isEmpty ? null : todayMatches.first;
    final chartEntries =
        sorted.length > 30 ? sorted.sublist(sorted.length - 30) : sorted;

    return SizedBox.expand(
        child: Column(
      children: [
        GlassAppBar(
          centerTitle: false,
          title: Text(
            'Weight',
            style: TextStyle(
              color: c.text,
              fontFamily: 'Playfair Display',
              fontSize: 24,
            ),
          ),
          actions: [
            IconButton(
              onPressed: () => context.push('/settings'),
              icon: Icon(Icons.settings_outlined, color: c.muted),
            ),
          ],
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'TREND · ${settings.weightUnit}',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        height: 120,
                        child: chartEntries.length >= 2
                            ? _WeightChart(
                                entries: chartEntries,
                                goalKg: goalKg,
                                fromKg: _fromKg,
                                color: c.mint,
                                goalColor: c.accent,
                              )
                            : Center(
                                child: Text(
                                  'Log at least 2 entries to see your trend',
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
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
                      Text(
                        'TODAY',
                        style: TextStyle(
                          color: c.muted,
                          fontSize: 10,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Text.rich(
                              TextSpan(
                                text: todayWeight != null
                                    ? _fromKg(todayWeight.weight)
                                        .toStringAsFixed(1)
                                    : '—',
                                children: [
                                  TextSpan(
                                    text: ' ${settings.weightUnit}',
                                    style: TextStyle(
                                      color: c.muted,
                                      fontSize: 14,
                                      fontFamily: 'DM Sans',
                                      fontWeight: FontWeight.w400,
                                    ),
                                  )
                                ],
                              ),
                              style: TextStyle(
                                color: todayWeight != null ? c.mint : c.muted,
                                fontFamily: 'DM Mono',
                                fontSize: 36,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 126,
                            child: PwaButton(
                              onPressed: () => setState(() {
                                _inputOpen = !_inputOpen;
                                _goalOpen = false;
                              }),
                              color: c.mint,
                              height: 42,
                              label: _inputOpen ? 'Cancel' : 'Log Weight',
                            ),
                          ),
                        ],
                      ),
                      if (goalKg != null) ...[
                        const SizedBox(height: 4),
                        Text.rich(
                          TextSpan(
                            text: 'Goal: ',
                            children: [
                              TextSpan(
                                text: _fmtWeight(goalKg),
                                style: TextStyle(color: c.accent),
                              ),
                              if (todayWeight != null)
                                TextSpan(
                                  text:
                                      ' (${_delta(todayWeight.weight, goalKg)})',
                                  style: TextStyle(color: c.muted),
                                ),
                            ],
                          ),
                          style: TextStyle(color: c.muted, fontSize: 11),
                        ),
                      ],
                      if (_inputOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: c.border)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 12),
                              child: Row(children: [
                                Expanded(
                                  child: _WeightInput(
                                    ctrl: _weightCtrl,
                                    unit: settings.weightUnit,
                                    color: c.mint,
                                    onSubmitted: _logWeight,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 86,
                                  child: PwaButton(
                                    onPressed: _logWeight,
                                    color: c.mint,
                                    height: 46,
                                    label: 'Save ✓',
                                  ),
                                ),
                              ]),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'GOAL WEIGHT',
                                  style: TextStyle(
                                    color: c.muted,
                                    fontSize: 10,
                                    letterSpacing: 1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  goalKg != null
                                      ? _fmtWeight(goalKg)
                                      : 'Not set',
                                  style: TextStyle(
                                    color: goalKg != null ? c.accent : c.muted,
                                    fontSize: 15,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 94,
                            child: PwaButton(
                              onPressed: () => setState(() {
                                _goalOpen = !_goalOpen;
                                _inputOpen = false;
                                if (goalKg != null) {
                                  _goalCtrl.text =
                                      _fromKg(goalKg).toStringAsFixed(1);
                                }
                              }),
                              color: c.muted,
                              filled: false,
                              height: 34,
                              label: _goalOpen
                                  ? 'Cancel'
                                  : goalKg != null
                                      ? 'Edit'
                                      : 'Set goal',
                            ),
                          ),
                        ],
                      ),
                      if (_goalOpen)
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: Border(top: BorderSide(color: c.border)),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: _WeightInput(
                                      ctrl: _goalCtrl,
                                      unit: settings.weightUnit,
                                      color: c.accent,
                                      onSubmitted: _setGoal,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    width: 86,
                                    child: PwaButton(
                                      onPressed: _setGoal,
                                      color: c.accent,
                                      height: 46,
                                      label: 'Save ✓',
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (weights.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  Text(
                    'ALL ENTRIES',
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 10,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ...weights.map((e) => _WeightEntryTile(
                        entry: e,
                        displayWeight: _fmtWeight(e.weight),
                        onDelete: () => _confirmDelete(context, ref, e),
                      )),
                ] else ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Column(
                      children: [
                        const Text('⚖', style: TextStyle(fontSize: 32)),
                        const SizedBox(height: 10),
                        Text(
                          'Tap Log Weight to record your first entry',
                          style: TextStyle(color: c.muted, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 80),
              ],
            ),
          ),
        ),
      ],
    ));
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
                  color: c.text, fontWeight: FontWeight.w600, fontSize: 16)),
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

class _WeightInput extends StatelessWidget {
  final TextEditingController ctrl;
  final String unit;
  final Color color;
  final VoidCallback onSubmitted;

  const _WeightInput({
    required this.ctrl,
    required this.unit,
    required this.color,
    required this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))
              ],
              onSubmitted: (_) => onSubmitted(),
              style: TextStyle(
                color: color,
                fontFamily: 'DM Mono',
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              decoration: const InputDecoration(
                hintText: '0.0',
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          Text(unit, style: TextStyle(color: c.muted, fontSize: 13)),
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
    final chartMinY = (minY - yPad).floorToDouble();
    final chartMaxY = (maxY + yPad).ceilToDouble();
    final yInterval = _axisInterval(chartMaxY - chartMinY);

    return LineChart(
      LineChartData(
        minY: chartMinY,
        maxY: chartMaxY,
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
              interval: yInterval,
              reservedSize: 36,
              getTitlesWidget: (v, _) => Text(
                v.toStringAsFixed(0),
                style: TextStyle(color: c.muted, fontSize: 10),
              ),
            ),
          ),
          bottomTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles:
              const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        extraLinesData: goalKg != null
            ? ExtraLinesData(horizontalLines: [
                HorizontalLine(
                  y: fromKg(goalKg!),
                  color: goalColor.withValues(alpha: 0.6),
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
              color: color.withValues(alpha: 0.08),
            ),
          ),
        ],
      ),
    );
  }

  double _axisInterval(double range) {
    if (range <= 6) return 1;
    if (range <= 12) return 2;
    if (range <= 30) return 5;
    return 10;
  }
}
