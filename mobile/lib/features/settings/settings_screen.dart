import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/models/app_settings.dart';
import '../../core/providers.dart';
import '../../core/repositories/isar_repository.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pwa_chrome.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _anthropicCtrl;
  late TextEditingController _openaiCtrl;
  late TextEditingController _tokenCtrl;
  late TextEditingController _serverUrlCtrl;
  late TextEditingController _calCtrl;
  late TextEditingController _protCtrl;
  late TextEditingController _carbCtrl;
  late TextEditingController _fatCtrl;
  late TextEditingController _fibCtrl;
  late TextEditingController _macroWeightCtrl;
  late TextEditingController _macroAgeCtrl;
  bool _macroHelpOpen = false;
  bool _macroLoading = false;
  String _macroGender = '';
  String _macroActivity = 'moderate';
  String _macroGoal = 'maintain';
  String? _macroError;

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _anthropicCtrl = TextEditingController(text: s.anthropicKey ?? '');
    _openaiCtrl = TextEditingController(text: s.openaiKey ?? '');
    _tokenCtrl = TextEditingController(text: s.serverToken ?? '');
    _serverUrlCtrl = TextEditingController(text: s.serverUrl ?? '');
    _calCtrl =
        TextEditingController(text: s.goalCalories?.toStringAsFixed(0) ?? '');
    _protCtrl =
        TextEditingController(text: s.goalProtein?.toStringAsFixed(0) ?? '');
    _carbCtrl =
        TextEditingController(text: s.goalCarbs?.toStringAsFixed(0) ?? '');
    _fatCtrl = TextEditingController(text: s.goalFat?.toStringAsFixed(0) ?? '');
    _fibCtrl =
        TextEditingController(text: s.goalFiber?.toStringAsFixed(0) ?? '');
    final profile = s.macroProfile;
    _macroHelpOpen = profile != null &&
        (profile.gender.isNotEmpty ||
            profile.weight != null ||
            profile.age != null);
    _macroGender = profile?.gender ?? '';
    _macroActivity = profile?.activityLevel ?? 'moderate';
    _macroGoal = profile?.goal ?? 'maintain';
    _macroWeightCtrl =
        TextEditingController(text: profile?.weight?.toStringAsFixed(1) ?? '');
    _macroAgeCtrl = TextEditingController(text: profile?.age?.toString() ?? '');
  }

  String _targetText(double? value) => value?.toStringAsFixed(0) ?? '';

  bool _targetFieldsMatch(AppSettings settings) {
    return _calCtrl.text == _targetText(settings.goalCalories) &&
        _protCtrl.text == _targetText(settings.goalProtein) &&
        _carbCtrl.text == _targetText(settings.goalCarbs) &&
        _fatCtrl.text == _targetText(settings.goalFat) &&
        _fibCtrl.text == _targetText(settings.goalFiber);
  }

  void _syncTargetFields(AppSettings settings) {
    _calCtrl.text = _targetText(settings.goalCalories);
    _protCtrl.text = _targetText(settings.goalProtein);
    _carbCtrl.text = _targetText(settings.goalCarbs);
    _fatCtrl.text = _targetText(settings.goalFat);
    _fibCtrl.text = _targetText(settings.goalFiber);
  }

  @override
  void dispose() {
    _anthropicCtrl.dispose();
    _openaiCtrl.dispose();
    _tokenCtrl.dispose();
    _serverUrlCtrl.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _fibCtrl.dispose();
    _macroWeightCtrl.dispose();
    _macroAgeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(current.copyWith(
          anthropicKey: _anthropicCtrl.text.trim().isEmpty
              ? null
              : _anthropicCtrl.text.trim(),
          openaiKey:
              _openaiCtrl.text.trim().isEmpty ? null : _openaiCtrl.text.trim(),
          serverToken:
              _tokenCtrl.text.trim().isEmpty ? null : _tokenCtrl.text.trim(),
          serverUrl: _serverUrlCtrl.text.trim().isEmpty
              ? null
              : _serverUrlCtrl.text.trim(),
          goalCalories: double.tryParse(_calCtrl.text),
          goalProtein: double.tryParse(_protCtrl.text),
          goalCarbs: double.tryParse(_carbCtrl.text),
          goalFat: double.tryParse(_fatCtrl.text),
          goalFiber: double.tryParse(_fibCtrl.text),
        ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Settings saved')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AppSettings>(settingsProvider, (previous, next) {
      if (previous == null || _targetFieldsMatch(previous)) {
        _syncTargetFields(next);
      }
    });

    final settings = ref.watch(settingsProvider);
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      body: Column(
        children: [
          PwaTopBar(
            title: 'Settings',
            showBorder: true,
            leading: IconButton(
              icon: Icon(Icons.close, color: c.muted),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/today');
                }
              },
              style: IconButton.styleFrom(
                minimumSize: const Size(44, 44),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            trailing: TextButton(
              onPressed: _save,
              child: Text(
                'Save',
                style: TextStyle(
                  color: c.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── AI Provider ────────────────────────────────────────────
                const _SectionHeader('AI Provider'),
                _SegmentedRow(
                  options: const ['server', 'anthropic', 'openai'],
                  labels: const ['Server', 'Anthropic', 'OpenAI'],
                  selected: settings.provider,
                  onSelect: (v) => ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(provider: v)),
                  colors: [c.oai, c.plum, c.oai],
                ),
                const SizedBox(height: 12),

                if (settings.provider == 'server') ...[
                  _Field(
                      ctrl: _tokenCtrl,
                      label: 'Server token (optional)',
                      obscure: true),
                  const SizedBox(height: 8),
                  _Field(
                      ctrl: _serverUrlCtrl,
                      label: 'Server URL (leave blank for default)'),
                ],
                if (settings.provider == 'anthropic')
                  _Field(
                      ctrl: _anthropicCtrl,
                      label: 'Anthropic API key',
                      obscure: true),
                if (settings.provider == 'openai')
                  _Field(
                      ctrl: _openaiCtrl,
                      label: 'OpenAI API key',
                      obscure: true),

                const SizedBox(height: 24),

                // ── Appearance ─────────────────────────────────────────────
                const _SectionHeader('Theme'),
                _SegmentedRow(
                  options: const ['auto', 'light', 'dark'],
                  labels: const ['Auto', 'Light', 'Dark'],
                  selected: settings.theme,
                  onSelect: (v) => ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(theme: v)),
                  colors: [c.muted, c.accent, c.accent],
                ),

                const SizedBox(height: 24),

                // ── Weight unit ────────────────────────────────────────────
                const _SectionHeader('Weight Unit'),
                _SegmentedRow(
                  options: const ['kg', 'lbs'],
                  labels: const ['kg', 'lbs'],
                  selected: settings.weightUnit,
                  onSelect: (v) => ref
                      .read(settingsProvider.notifier)
                      .update(settings.copyWith(weightUnit: v)),
                  colors: [c.mint, c.mint],
                ),

                const SizedBox(height: 24),

                // ── Daily targets ──────────────────────────────────────────
                _MacroHelperPanel(
                  open: _macroHelpOpen,
                  loading: _macroLoading,
                  error: _macroError,
                  gender: _macroGender,
                  activity: _macroActivity,
                  goal: _macroGoal,
                  weightUnit: settings.weightUnit,
                  weightCtrl: _macroWeightCtrl,
                  ageCtrl: _macroAgeCtrl,
                  recommendation: settings.macroRecommendation,
                  onToggle: () =>
                      setState(() => _macroHelpOpen = !_macroHelpOpen),
                  onGender: (v) => setState(() => _macroGender = v),
                  onActivity: (v) => setState(() => _macroActivity = v),
                  onGoal: (v) => setState(() => _macroGoal = v),
                  onChoose: () => _chooseTargets(context),
                ),
                const SizedBox(height: 12),
                _Field(ctrl: _calCtrl, label: 'Calories (kcal)', numeric: true),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _protCtrl,
                          label: 'Protein (g)',
                          numeric: true)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Field(
                          ctrl: _carbCtrl, label: 'Carbs (g)', numeric: true)),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                      child: _Field(
                          ctrl: _fatCtrl, label: 'Fat (g)', numeric: true)),
                  const SizedBox(width: 8),
                  Expanded(
                      child: _Field(
                          ctrl: _fibCtrl, label: 'Fiber (g)', numeric: true)),
                ]),

                const SizedBox(height: 24),

                // ── Data ───────────────────────────────────────────────────
                const _SectionHeader('Data'),
                _ActionTile(
                  icon: Icons.upload_outlined,
                  label: 'Export backup',
                  color: c.accent,
                  onTap: () => _export(context),
                ),
                const SizedBox(height: 8),
                _ActionTile(
                  icon: Icons.download_outlined,
                  label: 'Import backup',
                  color: c.sky,
                  onTap: () => _import(context, ref),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _export(BuildContext context) async {
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
      final parsed = jsonDecode(raw);
      final json = parsed is List
          ? <String, dynamic>{'meals': parsed}
          : Map<String, dynamic>.from(parsed as Map);
      final importResult =
          await ref.read(mealsProvider.notifier).importJson(json);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Imported ${importResult.meals} meals, ${importResult.weights} weights'),
      ));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
  }

  Future<void> _chooseTargets(BuildContext context) async {
    final weight = double.tryParse(_macroWeightCtrl.text);
    final age = int.tryParse(_macroAgeCtrl.text);
    if (_macroGender.isEmpty) {
      setState(() => _macroError = 'Choose a gender.');
      return;
    }
    if (weight == null || weight <= 0) {
      setState(() => _macroError = 'Enter your weight.');
      return;
    }
    if (age == null || age < 7 || age > 100) {
      setState(() => _macroError = 'Enter an age between 7 and 100.');
      return;
    }

    final profile = MacroProfile(
      gender: _macroGender,
      weight: weight,
      age: age,
      activityLevel: _macroActivity,
      goal: _macroGoal,
      updatedAt: DateTime.now().toIso8601String(),
    );

    setState(() {
      _macroLoading = true;
      _macroError = null;
    });

    try {
      final current = ref.read(settingsProvider);
      final result = await ref
          .read(aiServiceProvider)
          .chooseTargets(settings: current, profile: profile);
      _calCtrl.text = result.calories.toStringAsFixed(0);
      _protCtrl.text = result.protein.toStringAsFixed(0);
      _carbCtrl.text = result.carbs.toStringAsFixed(0);
      _fatCtrl.text = result.fat.toStringAsFixed(0);
      await ref.read(settingsProvider.notifier).update(current.copyWith(
            goalCalories: result.calories,
            goalProtein: result.protein,
            goalCarbs: result.carbs,
            goalFat: result.fat,
            macroProfile: profile,
            macroRecommendation: result,
          ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _macroError = _friendlyError(e));
    } finally {
      if (mounted) setState(() => _macroLoading = false);
    }
  }

  String _friendlyError(Object error) {
    return error
        .toString()
        .replaceFirst('Exception: ', '')
        .split('Source stack:')
        .first
        .trim();
  }
}

// ── Shared sub-widgets ─────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(title,
          style: TextStyle(
              color: c.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.6)),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool obscure;
  final bool numeric;

  const _Field({
    required this.ctrl,
    required this.label,
    this.obscure = false,
    this.numeric = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      obscureText: obscure,
      keyboardType: numeric ? TextInputType.number : TextInputType.text,
      inputFormatters:
          numeric ? [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))] : [],
      decoration: InputDecoration(labelText: label),
    );
  }
}

class _SegmentedRow extends StatelessWidget {
  final List<String> options;
  final List<String> labels;
  final List<Color> colors;
  final String selected;
  final ValueChanged<String> onSelect;

  const _SegmentedRow({
    required this.options,
    required this.labels,
    required this.colors,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Row(
      children: List.generate(options.length, (i) {
        final isSelected = options[i] == selected;
        return Expanded(
          child: GestureDetector(
            onTap: () => onSelect(options[i]),
            child: Container(
              margin: EdgeInsets.only(right: i < options.length - 1 ? 6 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isSelected ? colors[i].withValues(alpha: 0.15) : c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected ? colors[i] : c.border, width: 1.5),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colors[i] : c.muted,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: c.border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 12),
            Text(label, style: TextStyle(color: c.text)),
          ],
        ),
      ),
    );
  }
}

class _MacroHelperPanel extends StatelessWidget {
  final bool open;
  final bool loading;
  final String? error;
  final String gender;
  final String activity;
  final String goal;
  final String weightUnit;
  final TextEditingController weightCtrl;
  final TextEditingController ageCtrl;
  final MacroRecommendation? recommendation;
  final VoidCallback onToggle;
  final ValueChanged<String> onGender;
  final ValueChanged<String> onActivity;
  final ValueChanged<String> onGoal;
  final VoidCallback onChoose;

  const _MacroHelperPanel({
    required this.open,
    required this.loading,
    required this.error,
    required this.gender,
    required this.activity,
    required this.goal,
    required this.weightUnit,
    required this.weightCtrl,
    required this.ageCtrl,
    required this.recommendation,
    required this.onToggle,
    required this.onGender,
    required this.onActivity,
    required this.onGoal,
    required this.onChoose,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _MacroSectionLabel('Daily Targets', bottomPadding: 5),
                    Text('Macro and calorie setup',
                        style: TextStyle(
                            color: c.text,
                            fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      'Use AI to estimate targets from your body weight, age, activity, and goal.',
                      style:
                          TextStyle(color: c.muted, fontSize: 11, height: 1.5),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: onToggle,
                style: FilledButton.styleFrom(
                  backgroundColor: c.oai,
                  foregroundColor: AppColors.darkBg,
                  minimumSize: const Size(0, 42),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                child: Text(open ? 'Hide' : 'Help me choose'),
              ),
            ],
          ),
          if (open) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Text(
                'These details are saved with Settings, and AI-chosen targets are saved immediately after they are generated. AI-generated nutrition guidance can be wrong. Treat it as a starting point, especially if you have a medical condition, are pregnant, have a history of disordered eating, or train for performance.',
                style: TextStyle(color: c.muted, fontSize: 11, height: 1.55),
              ),
            ),
            const SizedBox(height: 12),
            const _MacroSectionLabel('Gender', bottomPadding: 7),
            Row(children: [
              Expanded(
                child: _ChoiceButton(
                  active: gender == 'female',
                  label: 'Female',
                  onTap: () => onGender('female'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceButton(
                  active: gender == 'male',
                  label: 'Male',
                  onTap: () => onGender('male'),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: _MacroNumberField(
                  ctrl: weightCtrl,
                  label: 'Weight',
                  unit: weightUnit,
                  color: c.mint,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MacroNumberField(
                  ctrl: ageCtrl,
                  label: 'Age',
                  placeholder: 'Years',
                  color: c.accent,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            const _MacroSectionLabel('Activity level', bottomPadding: 7),
            _ChoiceWrap(
              selected: activity,
              options: const [
                ('sedentary', 'Sedentary', 'Mostly seated'),
                ('light', 'Light', '1-3 workouts/week'),
                ('moderate', 'Moderate', '3-5 workouts/week'),
                ('very_active', 'Very active', 'Hard training most days'),
              ],
              onSelect: onActivity,
            ),
            const SizedBox(height: 12),
            const _MacroSectionLabel('Goal', bottomPadding: 7),
            Row(children: [
              Expanded(
                child: _ChoiceButton(
                    active: goal == 'lose',
                    label: 'Lose',
                    onTap: () => onGoal('lose')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceButton(
                    active: goal == 'maintain',
                    label: 'Maintain',
                    onTap: () => onGoal('maintain')),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ChoiceButton(
                    active: goal == 'gain',
                    label: 'Gain',
                    onTap: () => onGoal('gain')),
              ),
            ]),
            const SizedBox(height: 12),
            PwaButton(
              label: loading ? 'Choosing targets...' : 'Choose my targets',
              onPressed: loading ? null : onChoose,
              color: c.oai,
              height: 50,
            ),
            if (error != null && error!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(error!, style: TextStyle(color: c.danger, fontSize: 12)),
            ],
            if (recommendation != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: c.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: c.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        _ResultChip(
                            'Cal', recommendation!.calories, 'kcal', c.accent),
                        const SizedBox(width: 8),
                        _ResultChip(
                            'Protein', recommendation!.protein, 'g', c.mint),
                        const SizedBox(width: 8),
                        _ResultChip('Carbs', recommendation!.carbs, 'g', c.sky),
                        const SizedBox(width: 8),
                        _ResultChip('Fat', recommendation!.fat, 'g', c.peach),
                      ],
                    ),
                    if (recommendation!.method != null) ...[
                      const SizedBox(height: 10),
                      Text(recommendation!.method!,
                          style: TextStyle(color: c.muted, fontSize: 11)),
                    ],
                    if (recommendation!.explanation != null) ...[
                      const SizedBox(height: 6),
                      Text(recommendation!.explanation!,
                          style: TextStyle(color: c.text, fontSize: 12)),
                    ],
                    if (recommendation!.cautions != null) ...[
                      const SizedBox(height: 6),
                      Text(recommendation!.cautions!,
                          style: TextStyle(color: c.muted, fontSize: 11)),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _ChoiceWrap extends StatelessWidget {
  final String selected;
  final List<(String, String, String)> options;
  final ValueChanged<String> onSelect;

  const _ChoiceWrap({
    required this.selected,
    required this.options,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 8.0;
        final itemWidth = (constraints.maxWidth - gap) / 2;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: options
              .map((o) => SizedBox(
                    width: itemWidth,
                    child: _ChoiceButton(
                      active: selected == o.$1,
                      label: o.$2,
                      sub: o.$3,
                      onTap: () => onSelect(o.$1),
                    ),
                  ))
              .toList(),
        );
      },
    );
  }
}

class _MacroSectionLabel extends StatelessWidget {
  final String label;
  final double bottomPadding;

  const _MacroSectionLabel(this.label, {this.bottomPadding = 6});

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: c.muted,
          fontSize: 10,
          letterSpacing: 1.3,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _MacroNumberField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final String? unit;
  final String? placeholder;
  final Color color;

  const _MacroNumberField({
    required this.ctrl,
    required this.label,
    this.unit,
    this.placeholder,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _MacroSectionLabel(label),
        Container(
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
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[\d.]')),
                  ],
                  style: TextStyle(
                    color: color,
                    fontSize: 18,
                    fontFamily: 'DM Mono',
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: placeholder,
                    hintStyle: TextStyle(color: c.muted, fontSize: 14),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              if (unit != null)
                Text(unit!, style: TextStyle(color: c.muted, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  final bool active;
  final String label;
  final String? sub;
  final VoidCallback onTap;

  const _ChoiceButton({
    required this.active,
    required this.label,
    this.sub,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: active ? c.oai.withValues(alpha: 0.12) : c.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: active ? c.oai : c.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: active ? c.oai : c.text,
                    fontSize: 13,
                    fontWeight: FontWeight.w700),
              ),
              if (sub != null) ...[
                const SizedBox(height: 2),
                Text(
                  sub!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.muted, fontSize: 10, height: 1.35),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultChip extends StatelessWidget {
  final String label;
  final double value;
  final String unit;
  final Color color;

  const _ResultChip(this.label, this.value, this.unit, this.color);

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: c.border),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: c.muted,
                fontSize: 9,
                letterSpacing: 1.0,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              value.toStringAsFixed(0),
              style: TextStyle(
                color: color,
                fontSize: 15,
                fontFamily: 'DM Mono',
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(unit, style: TextStyle(color: c.muted, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}
