import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/providers.dart';
import '../../core/repositories/isar_repository.dart';
import '../../core/theme/app_theme.dart';

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

  @override
  void initState() {
    super.initState();
    final s = ref.read(settingsProvider);
    _anthropicCtrl = TextEditingController(text: s.anthropicKey ?? '');
    _openaiCtrl = TextEditingController(text: s.openaiKey ?? '');
    _tokenCtrl = TextEditingController(text: s.serverToken ?? '');
    _serverUrlCtrl = TextEditingController(text: s.serverUrl ?? '');
    _calCtrl = TextEditingController(
        text: s.goalCalories?.toStringAsFixed(0) ?? '');
    _protCtrl =
        TextEditingController(text: s.goalProtein?.toStringAsFixed(0) ?? '');
    _carbCtrl =
        TextEditingController(text: s.goalCarbs?.toStringAsFixed(0) ?? '');
    _fatCtrl =
        TextEditingController(text: s.goalFat?.toStringAsFixed(0) ?? '');
    _fibCtrl =
        TextEditingController(text: s.goalFiber?.toStringAsFixed(0) ?? '');
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
    super.dispose();
  }

  Future<void> _save() async {
    final current = ref.read(settingsProvider);
    await ref.read(settingsProvider.notifier).update(current.copyWith(
          anthropicKey: _anthropicCtrl.text.trim().isEmpty
              ? null
              : _anthropicCtrl.text.trim(),
          openaiKey: _openaiCtrl.text.trim().isEmpty
              ? null
              : _openaiCtrl.text.trim(),
          serverToken: _tokenCtrl.text.trim().isEmpty
              ? null
              : _tokenCtrl.text.trim(),
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
    final settings = ref.watch(settingsProvider);
    final c = context.appColors;

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text('Settings', style: TextStyle(color: c.text)),
        actions: [
          TextButton(
            onPressed: _save,
            child: Text('Save', style: TextStyle(color: c.accent)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── AI Provider ────────────────────────────────────────────
          _SectionHeader('AI Provider'),
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
                ctrl: _anthropicCtrl, label: 'Anthropic API key', obscure: true),
          if (settings.provider == 'openai')
            _Field(ctrl: _openaiCtrl, label: 'OpenAI API key', obscure: true),

          const SizedBox(height: 24),

          // ── Appearance ─────────────────────────────────────────────
          _SectionHeader('Theme'),
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
          _SectionHeader('Weight Unit'),
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
          _SectionHeader('Daily Targets'),
          _Field(ctrl: _calCtrl, label: 'Calories (kcal)', numeric: true),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(ctrl: _protCtrl, label: 'Protein (g)', numeric: true)),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _carbCtrl, label: 'Carbs (g)', numeric: true)),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _Field(ctrl: _fatCtrl, label: 'Fat (g)', numeric: true)),
            const SizedBox(width: 8),
            Expanded(child: _Field(ctrl: _fibCtrl, label: 'Fiber (g)', numeric: true)),
          ]),

          const SizedBox(height: 24),

          // ── Data ───────────────────────────────────────────────────
          _SectionHeader('Data'),
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
      await Share.shareXFiles([XFile(file.path)], subject: 'Meal Tracker backup');
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Export failed: $e')));
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
      final importResult =
          await ref.read(mealsProvider.notifier).importJson(json);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Imported ${importResult.meals} meals, ${importResult.weights} weights'),
      ));
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
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
              color: c.muted, fontSize: 12, fontWeight: FontWeight.w600,
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
              decoration: BoxDecoration(
                color: isSelected ? colors[i].withOpacity(0.15) : c.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: isSelected ? colors[i] : c.border, width: 1.5),
              ),
              child: Text(
                labels[i],
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? colors[i] : c.muted,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
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

// Extension so AppColorsExtension exposes oai
extension _OaiColor on AppColorsExtension {
  Color get oai => AppColors.oai;
}
