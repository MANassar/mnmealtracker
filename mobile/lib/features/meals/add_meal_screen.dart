import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

import '../../core/models/meal.dart';
import '../../core/providers.dart';
import '../../core/services/ai/meal_analysis.dart';
import '../../core/theme/app_theme.dart';
import '../../shared/widgets/pwa_chrome.dart';

enum _Status { idle, analyzing, review, optimizing }

class AddMealScreen extends ConsumerStatefulWidget {
  final Meal? editingMeal;
  final Meal? repeatMeal;
  final String returnPath;

  const AddMealScreen({
    super.key,
    this.editingMeal,
    this.repeatMeal,
    this.returnPath = '/today',
  });

  @override
  ConsumerState<AddMealScreen> createState() => _AddMealScreenState();
}

class _AddMealScreenState extends ConsumerState<AddMealScreen> {
  final _descCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _calCtrl = TextEditingController();
  final _protCtrl = TextEditingController();
  final _carbCtrl = TextEditingController();
  final _fatCtrl = TextEditingController();
  final _fibCtrl = TextEditingController();

  File? _imageFile;
  _Status _status = _Status.idle;
  String? _error;
  MealAnalysis? _analysis;
  MealOptimization? _optimization;
  late String _mealDate;

  bool get _isEditing => widget.editingMeal != null;

  @override
  void initState() {
    super.initState();
    _mealDate = _todayStr();
    final source = widget.editingMeal ?? widget.repeatMeal;
    if (source != null) {
      _mealDate = widget.editingMeal != null ? source.date : _todayStr();
      _nameCtrl.text = source.mealName;
      _calCtrl.text = _fmt(source.calories);
      _protCtrl.text = _fmt(source.protein);
      _carbCtrl.text = _fmt(source.carbs);
      _fatCtrl.text = _fmt(source.fat);
      _fibCtrl.text = _fmt(source.fiber);
      _descCtrl.text = source.description ?? '';
      if (source.imagePath != null) {
        final f = File(source.imagePath!);
        if (f.existsSync()) _imageFile = f;
      }
      _analysis = MealAnalysis(
        mealName: source.mealName,
        calories: source.calories,
        protein: source.protein,
        carbs: source.carbs,
        fat: source.fat,
        fiber: source.fiber,
        portionNote: source.portionNote,
      );
      _status = _Status.review;
    }
  }

  @override
  void dispose() {
    _descCtrl.dispose();
    _nameCtrl.dispose();
    _calCtrl.dispose();
    _protCtrl.dispose();
    _carbCtrl.dispose();
    _fatCtrl.dispose();
    _fibCtrl.dispose();
    super.dispose();
  }

  String _fmt(double v) =>
      v == v.toInt() ? v.toInt().toString() : v.toStringAsFixed(1);

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
      maxHeight: 1200,
    );
    if (picked == null) return;

    // Compress further if needed
    final tmpDir = await getTemporaryDirectory();
    final outPath =
        '${tmpDir.path}/meal_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final compressed = await FlutterImageCompress.compressAndGetFile(
      picked.path,
      outPath,
      quality: 72,
      minWidth: 800,
      minHeight: 800,
    );

    setState(() {
      _imageFile =
          compressed != null ? File(compressed.path) : File(picked.path);
      _status = _Status.idle;
      _analysis = null;
      _optimization = null;
    });
  }

  void _showImagePicker() {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Camera'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Photo library'),
              onTap: () {
                Navigator.pop(context);
                _pickImage(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();

    if (_imageFile == null && _descCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Add a photo or description first.');
      return;
    }

    setState(() {
      _status = _Status.analyzing;
      _error = null;
    });

    try {
      final settings = ref.read(settingsProvider);
      final ai = ref.read(aiServiceProvider);
      final result = await ai.analyze(
        settings: settings,
        imageFile: _imageFile,
        description: _descCtrl.text.trim(),
      );

      _applyAnalysis(result);
      setState(() {
        _analysis = result;
        _status = _Status.review;
      });
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _status = _Status.idle;
      });
    }
  }

  Future<void> _optimize() async {
    if (_analysis == null) return;
    setState(() {
      _status = _Status.optimizing;
      _error = null;
    });

    try {
      final settings = ref.read(settingsProvider);
      final ai = ref.read(aiServiceProvider);
      final result = await ai.optimize(
        settings: settings,
        analysis: _analysis!,
        description: _descCtrl.text.trim(),
      );

      setState(() {
        _optimization = result;
        _status = _Status.review;
      });
    } catch (e) {
      setState(() {
        _error = _friendlyError(e);
        _status = _Status.review;
      });
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

  void _applyAnalysis(MealAnalysis a) {
    _nameCtrl.text = a.mealName;
    _calCtrl.text = _fmt(a.calories);
    _protCtrl.text = _fmt(a.protein);
    _carbCtrl.text = _fmt(a.carbs);
    _fatCtrl.text = _fmt(a.fat);
    _fibCtrl.text = _fmt(a.fiber);
  }

  void _applyPreviousMeal(Meal meal) {
    FocusScope.of(context).unfocus();

    final imagePath = meal.imagePath;
    final imageFile = imagePath == null ? null : File(imagePath);
    setState(() {
      _mealDate = _todayStr();
      _nameCtrl.text = meal.mealName;
      _calCtrl.text = _fmt(meal.calories);
      _protCtrl.text = _fmt(meal.protein);
      _carbCtrl.text = _fmt(meal.carbs);
      _fatCtrl.text = _fmt(meal.fat);
      _fibCtrl.text = _fmt(meal.fiber);
      _descCtrl.text = meal.description ?? '';
      _imageFile =
          imageFile != null && imageFile.existsSync() ? imageFile : null;
      _analysis = MealAnalysis(
        mealName: meal.mealName,
        calories: meal.calories,
        protein: meal.protein,
        carbs: meal.carbs,
        fat: meal.fat,
        fiber: meal.fiber,
        ingredients: _ingredientsFromJson(meal.ingredients),
        confidence: meal.confidence,
        portionNote: meal.portionNote,
      );
      _optimization = null;
      _error = null;
      _status = _Status.review;
    });
  }

  List<String> _ingredientsFromJson(String? raw) {
    if (raw == null || raw.trim().isEmpty) return const [];
    try {
      final parsed = jsonDecode(raw);
      if (parsed is! List) return const [];
      return parsed.map((item) => item.toString()).toList();
    } catch (_) {
      return const [];
    }
  }

  List<Meal> _previousMeals(List<Meal> meals) {
    final sorted = [...meals]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final seen = <String>{};
    final previous = <Meal>[];

    for (final meal in sorted) {
      final key = [
        meal.mealName.trim().toLowerCase(),
        meal.calories.toStringAsFixed(1),
        meal.protein.toStringAsFixed(1),
        meal.carbs.toStringAsFixed(1),
        meal.fat.toStringAsFixed(1),
        meal.fiber.toStringAsFixed(1),
      ].join('|');
      if (!seen.add(key)) continue;
      previous.add(meal);
      if (previous.length == 6) break;
    }

    return previous;
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a meal name.');
      return;
    }

    final cal = double.tryParse(_calCtrl.text) ?? 0;
    final prot = double.tryParse(_protCtrl.text) ?? 0;
    final carb = double.tryParse(_carbCtrl.text) ?? 0;
    final fat = double.tryParse(_fatCtrl.text) ?? 0;
    final fib = double.tryParse(_fibCtrl.text) ?? 0;

    // Save photo to permanent storage
    String? savedImagePath;
    if (_imageFile != null) {
      final dir = await getApplicationDocumentsDirectory();
      final dest = '${dir.path}/meal_photos/${const Uuid().v4()}.jpg';
      await Directory('${dir.path}/meal_photos').create(recursive: true);
      if (_isEditing &&
          widget.editingMeal!.imagePath != null &&
          widget.editingMeal!.imagePath != _imageFile!.path) {
        // New photo chosen during edit — keep the new one
      }
      await _imageFile!.copy(dest);
      savedImagePath = dest;
    }

    final settings = ref.read(settingsProvider);
    final meal = widget.editingMeal ?? Meal();
    final uuid = widget.editingMeal?.uuid ?? const Uuid().v4();
    meal
      ..uuid = uuid.isEmpty ? const Uuid().v4() : uuid
      ..date = _mealDate
      ..timestamp =
          widget.editingMeal?.timestamp ?? DateTime.now().millisecondsSinceEpoch
      ..mealName = name
      ..calories = cal
      ..protein = prot
      ..carbs = carb
      ..fat = fat
      ..fiber = fib
      ..provider = settings.provider
      ..description =
          _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim()
      ..portionNote = _analysis?.portionNote
      ..confidence = _analysis?.confidence
      ..ingredients = _analysis?.ingredients.isNotEmpty == true
          ? jsonEncode(_analysis!.ingredients)
          : null;

    if (savedImagePath != null) meal.imagePath = savedImagePath;

    await ref.read(mealsProvider.notifier).save(meal);
    if (mounted) context.go(widget.returnPath);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final isLoading =
        _status == _Status.analyzing || _status == _Status.optimizing;
    final title = _isEditing ? 'Edit Meal' : 'Add Meal';
    final previousMeals = _previousMeals(ref.watch(mealsProvider));

    return GlassScaffold(
      backgroundColor: c.bg,
      statusBarStyle: GlassStatusBarStyle.auto,
      extendBody: false,
      appBar: GlassAppBar(
        title: Text(title),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: c.muted),
          onPressed: () => context.go(widget.returnPath),
          style: IconButton.styleFrom(
            minimumSize: const Size(44, 44),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        actions: [_ProviderPill(provider: ref.watch(settingsProvider).provider)],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _showImagePicker,
                    child: Container(
                      height: _imageFile != null ? 220 : 160,
                      decoration: BoxDecoration(
                        color: c.card,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: _imageFile != null ? c.border : c.muted,
                          width: _imageFile != null ? 1 : 2,
                        ),
                      ),
                      child: _imageFile != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.file(
                                _imageFile!,
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: 240,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.camera_alt_outlined,
                                    color: c.muted, size: 42),
                                const SizedBox(height: 8),
                                Text('Add a photo',
                                    style: TextStyle(
                                        color: c.muted,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500)),
                                const SizedBox(height: 3),
                                Text('optional if you describe the meal',
                                    style: TextStyle(
                                        color: c.muted, fontSize: 12)),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descCtrl,
                    decoration: InputDecoration(
                      hintText:
                          'Describe the meal, portions, ingredients, or restaurant…',
                      filled: true,
                      fillColor: c.card,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(color: c.border),
                      ),
                    ),
                    maxLines: 3,
                    textInputAction: TextInputAction.done,
                  ),
                  if (!_isEditing &&
                      _status == _Status.idle &&
                      previousMeals.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _PreviousMealsPanel(
                      meals: previousMeals,
                      onSelect: _applyPreviousMeal,
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: c.danger.withValues(alpha: 0.12),
                        border: Border.all(color: c.danger),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_error!,
                          style: TextStyle(color: c.danger, fontSize: 13)),
                    ),
                  ],
                  if (_status == _Status.review && _analysis != null) ...[
                    const SizedBox(height: 12),
                    _AnalysisEditor(
                      analysis: _analysis!,
                      nameCtrl: _nameCtrl,
                      calCtrl: _calCtrl,
                      protCtrl: _protCtrl,
                      carbCtrl: _carbCtrl,
                      fatCtrl: _fatCtrl,
                      fibCtrl: _fibCtrl,
                      provider: ref.watch(settingsProvider).provider,
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 12),
                      _OptimizationPanel(
                        optimization: _optimization,
                        isOptimizing: _status == _Status.optimizing,
                        onOptimize: _optimize,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _MealDateEditor(
                      date: _mealDate,
                      onChanged: (value) => setState(() => _mealDate = value),
                    )
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          Container(
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              16,
              MediaQuery.of(context).padding.bottom + 10,
            ),
            decoration: BoxDecoration(
              color: c.bg,
              border: Border(top: BorderSide(color: c.border)),
            ),
            child: _status == _Status.review
                ? Row(
                    children: [
                      Expanded(
                        child: PwaButton(
                          onPressed: isLoading ? null : _analyze,
                          color: c.muted,
                          filled: false,
                          height: 54,
                          label: 'Re-analyze',
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        flex: 2,
                        child: PwaButton(
                          onPressed: isLoading ? null : _save,
                          color: c.accent,
                          height: 54,
                          label: _isEditing ? 'Save Meal ✓' : 'Log Meal ✓',
                        ),
                      ),
                    ],
                  )
                : SizedBox(
                    width: double.infinity,
                    child: PwaButton(
                      onPressed: isLoading ? null : _analyze,
                      color: c.accent,
                      height: 54,
                      label: isLoading ? 'Analyzing…' : 'Analyze Meal',
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _AnalysisEditor extends StatelessWidget {
  final MealAnalysis analysis;
  final TextEditingController nameCtrl;
  final TextEditingController calCtrl;
  final TextEditingController protCtrl;
  final TextEditingController carbCtrl;
  final TextEditingController fatCtrl;
  final TextEditingController fibCtrl;
  final String? provider;

  const _AnalysisEditor({
    required this.analysis,
    required this.nameCtrl,
    required this.calCtrl,
    required this.protCtrl,
    required this.carbCtrl,
    required this.fatCtrl,
    required this.fibCtrl,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pc = providerColor(context, provider);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pc.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: nameCtrl,
            style: TextStyle(
              color: c.text,
              fontFamily: 'Playfair Display',
              fontSize: 18,
            ),
            decoration: const InputDecoration(
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Text('Calories',
                    style: TextStyle(color: c.muted, fontSize: 12)),
                const Spacer(),
                SizedBox(
                  width: 72,
                  child:
                      _BareNumberField(ctrl: calCtrl, color: pc, fontSize: 22),
                ),
                const SizedBox(width: 8),
                Text('kcal', style: TextStyle(color: c.muted, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _NutritionTile(label: 'Protein', ctrl: protCtrl, color: c.mint),
              const SizedBox(width: 8),
              _NutritionTile(label: 'Carbs', ctrl: carbCtrl, color: c.sky),
              const SizedBox(width: 8),
              _NutritionTile(label: 'Fat', ctrl: fatCtrl, color: c.peach),
              const SizedBox(width: 8),
              _NutritionTile(label: 'Fiber', ctrl: fibCtrl, color: c.plum),
            ],
          ),
          if (analysis.portionNote != null &&
              analysis.portionNote!.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: pc.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border(left: BorderSide(color: pc, width: 2)),
              ),
              child: Text(
                analysis.portionNote!,
                style: TextStyle(
                  color: c.muted,
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _PreviousMealsPanel extends StatelessWidget {
  final List<Meal> meals;
  final ValueChanged<Meal> onSelect;

  const _PreviousMealsPanel({
    required this.meals,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'PREVIOUS MEALS',
            style: TextStyle(
              color: c.muted,
              fontSize: 10,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 8),
          ...meals.map(
            (meal) => _PreviousMealTile(
              meal: meal,
              onTap: () => onSelect(meal),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviousMealTile extends StatelessWidget {
  final Meal meal;
  final VoidCallback onTap;

  const _PreviousMealTile({
    required this.meal,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    final pc = providerColor(context, meal.provider);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    meal.mealName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${meal.calories.round()} kcal  ·  '
                    '${meal.protein.toStringAsFixed(0)}P '
                    '${meal.carbs.toStringAsFixed(0)}C '
                    '${meal.fat.toStringAsFixed(0)}F',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: c.muted,
                      fontSize: 11,
                      fontFamily: 'DM Mono',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.add_circle_outline, color: pc, size: 22),
          ],
        ),
      ),
    );
  }
}

class _NutritionTile extends StatelessWidget {
  final String label;
  final TextEditingController ctrl;
  final Color color;

  const _NutritionTile({
    required this.label,
    required this.ctrl,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            _BareNumberField(ctrl: ctrl, color: color, fontSize: 16),
            const SizedBox(height: 5),
            Text(
              label.toUpperCase(),
              style: TextStyle(
                color: c.muted,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BareNumberField extends StatelessWidget {
  final TextEditingController ctrl;
  final Color color;
  final double fontSize;

  const _BareNumberField({
    required this.ctrl,
    required this.color,
    required this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      textAlign: TextAlign.center,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontFamily: 'DM Mono',
        fontWeight: FontWeight.w700,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
        enabledBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: color)),
        focusedBorder:
            UnderlineInputBorder(borderSide: BorderSide(color: color)),
      ),
    );
  }
}

class _OptimizationPanel extends StatelessWidget {
  final MealOptimization? optimization;
  final bool isOptimizing;
  final VoidCallback onOptimize;

  const _OptimizationPanel({
    required this.optimization,
    required this.isOptimizing,
    required this.onOptimize,
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
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CALORIE OPTIMIZATION',
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 10,
                        letterSpacing: 1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Ask AI for a lower-calorie version before logging.',
                      style:
                          TextStyle(color: c.text, fontSize: 13, height: 1.35),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              PwaButton(
                label: isOptimizing
                    ? 'Optimizing…'
                    : optimization == null
                        ? 'Optimize'
                        : 'Try Again',
                onPressed: isOptimizing ? null : onOptimize,
                color: c.oai,
                filled: false,
                height: 40,
              ),
            ],
          ),
          if (optimization != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.oai.withValues(alpha: 0.18)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          optimization!.mealName,
                          style: TextStyle(
                            color: c.text,
                            fontFamily: 'Playfair Display',
                            fontSize: 17,
                          ),
                        ),
                      ),
                      Text(
                        '${optimization!.calories.round()} kcal',
                        style: TextStyle(
                          color: c.oai,
                          fontFamily: 'DM Mono',
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  if (optimization!.calorieSavings != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '-${optimization!.calorieSavings!.round()} kcal estimated',
                      style: TextStyle(
                        color: c.mint,
                        fontFamily: 'DM Mono',
                        fontSize: 11,
                      ),
                    ),
                  ],
                  if (optimization!.portionNote != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      optimization!.portionNote!,
                      style: TextStyle(
                        color: c.muted,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MealDateEditor extends StatelessWidget {
  final String date;
  final ValueChanged<String> onChanged;

  const _MealDateEditor({
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.appColors;
    return GestureDetector(
      onTap: () async {
        final current = DateTime.tryParse('${date}T12:00:00') ?? DateTime.now();
        final picked = await showDatePicker(
          context: context,
          initialDate: current,
          firstDate: DateTime(2020),
          lastDate: DateTime.now().add(const Duration(days: 365)),
        );
        if (picked == null) return;
        onChanged(
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}',
        );
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: c.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'MEAL DATE',
              style: TextStyle(color: c.muted, fontSize: 10, letterSpacing: 1),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 13),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.border),
              ),
              child: Text(
                date,
                style: TextStyle(
                  color: c.text,
                  fontSize: 16,
                  fontFamily: 'DM Mono',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProviderPill extends StatelessWidget {
  final String? provider;

  const _ProviderPill({required this.provider});

  @override
  Widget build(BuildContext context) {
    final pc = providerColor(context, provider);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: providerBg(context, provider),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: pc),
      ),
      child: Text(
        providerLabel(provider).toUpperCase(),
        style: TextStyle(
          color: pc,
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}
