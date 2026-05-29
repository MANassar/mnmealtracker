import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  bool get _isEditing => widget.editingMeal != null;

  @override
  void initState() {
    super.initState();
    final source = widget.editingMeal ?? widget.repeatMeal;
    if (source != null) {
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
      // Pre-fill analysis from the source meal so edit shows review state
      if (widget.editingMeal != null) {
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
      _imageFile = compressed != null ? File(compressed.path) : File(picked.path);
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
        _error = e.toString().replaceFirst('Exception: ', '');
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
        _error = e.toString().replaceFirst('Exception: ', '');
        _status = _Status.review;
      });
    }
  }

  void _applyAnalysis(MealAnalysis a) {
    _nameCtrl.text = a.mealName;
    _calCtrl.text = _fmt(a.calories);
    _protCtrl.text = _fmt(a.protein);
    _carbCtrl.text = _fmt(a.carbs);
    _fatCtrl.text = _fmt(a.fat);
    _fibCtrl.text = _fmt(a.fiber);
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
      final dest =
          '${dir.path}/meal_photos/${const Uuid().v4()}.jpg';
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
    meal
      ..uuid = meal.uuid.isEmpty ? const Uuid().v4() : meal.uuid
      ..date = _todayStr()
      ..timestamp = widget.editingMeal?.timestamp ??
          DateTime.now().millisecondsSinceEpoch
      ..mealName = name
      ..calories = cal
      ..protein = prot
      ..carbs = carb
      ..fat = fat
      ..fiber = fib
      ..provider = settings.provider
      ..description = _descCtrl.text.trim().isEmpty
          ? null
          : _descCtrl.text.trim()
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
    final isLoading = _status == _Status.analyzing || _status == _Status.optimizing;
    final title = _isEditing
        ? 'Edit meal'
        : widget.repeatMeal != null
            ? 'Log again'
            : 'Log meal';

    return Scaffold(
      backgroundColor: c.bg,
      appBar: AppBar(
        backgroundColor: c.surface,
        title: Text(title, style: TextStyle(color: c.text)),
        leading: IconButton(
          icon: Icon(Icons.close, color: c.muted),
          onPressed: () => context.go(widget.returnPath),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Photo picker
            GestureDetector(
              onTap: _showImagePicker,
              child: Container(
                height: _imageFile != null ? 200 : 100,
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: c.border),
                ),
                child: _imageFile != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.file(
                          _imageFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                        ),
                      )
                    : Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt_outlined,
                              color: c.muted, size: 28),
                          const SizedBox(height: 6),
                          Text('Tap to add photo',
                              style: TextStyle(color: c.muted, fontSize: 13)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),

            // Description
            TextField(
              controller: _descCtrl,
              decoration: const InputDecoration(
                labelText: 'Description (optional)',
                hintText: 'e.g. grilled chicken salad, large portion',
              ),
              maxLines: 2,
              textInputAction: TextInputAction.done,
            ),

            const SizedBox(height: 12),

            // Analyze button
            if (_status != _Status.review)
              ElevatedButton.icon(
                onPressed: isLoading ? null : _analyze,
                icon: isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.auto_awesome),
                label: Text(isLoading ? 'Analyzing…' : 'Analyze with AI'),
              ),

            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!,
                  style: TextStyle(color: c.danger, fontSize: 13)),
            ],

            const SizedBox(height: 20),

            // Nutrition fields
            Text('Nutrition',
                style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w600,
                    fontSize: 15)),
            const SizedBox(height: 10),

            _NutritionField(
                ctrl: _nameCtrl, label: 'Meal name', isText: true),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _NutritionField(
                      ctrl: _calCtrl, label: 'Calories (kcal)')),
              const SizedBox(width: 8),
              Expanded(
                  child: _NutritionField(
                      ctrl: _protCtrl, label: 'Protein (g)')),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                  child: _NutritionField(ctrl: _carbCtrl, label: 'Carbs (g)')),
              const SizedBox(width: 8),
              Expanded(
                  child: _NutritionField(ctrl: _fatCtrl, label: 'Fat (g)')),
            ]),
            const SizedBox(height: 8),
            _NutritionField(ctrl: _fibCtrl, label: 'Fiber (g)'),

            // Analysis review panel
            if (_status == _Status.review && _analysis != null) ...[
              const SizedBox(height: 20),
              _ReviewPanel(
                analysis: _analysis!,
                optimization: _optimization,
                onOptimize: _status == _Status.optimizing ? null : _optimize,
                isOptimizing: _status == _Status.optimizing,
              ),
            ],

            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: isLoading ? null : _save,
              child: Text(_isEditing ? 'Save changes' : 'Log meal'),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _todayStr() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
}

class _NutritionField extends StatelessWidget {
  final TextEditingController ctrl;
  final String label;
  final bool isText;

  const _NutritionField({
    required this.ctrl,
    required this.label,
    this.isText = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: ctrl,
      decoration: InputDecoration(labelText: label),
      keyboardType: isText ? TextInputType.text : TextInputType.number,
      inputFormatters: isText
          ? []
          : [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
    );
  }
}

class _ReviewPanel extends StatelessWidget {
  final MealAnalysis analysis;
  final MealOptimization? optimization;
  final VoidCallback? onOptimize;
  final bool isOptimizing;

  const _ReviewPanel({
    required this.analysis,
    this.optimization,
    this.onOptimize,
    this.isOptimizing = false,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: c.accent),
            const SizedBox(width: 6),
            Text('AI Analysis',
                style: TextStyle(
                    color: c.text, fontWeight: FontWeight.w600)),
            const Spacer(),
            if (analysis.confidence != null)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: _confidenceColor(context, analysis.confidence!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(analysis.confidence!,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 11)),
              ),
          ]),

          if (analysis.portionNote != null) ...[
            const SizedBox(height: 8),
            Text(analysis.portionNote!,
                style: TextStyle(color: c.muted, fontSize: 13)),
          ],

          if (analysis.ingredients.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text('Ingredients detected:',
                style: TextStyle(
                    color: c.muted, fontSize: 12)),
            const SizedBox(height: 4),
            ...analysis.ingredients.map((i) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text('• $i',
                      style: TextStyle(
                          color: c.text, fontSize: 13)),
                )),
          ],

          // Optimization result
          if (optimization != null) ...[
            const Divider(height: 20),
            Row(children: [
              Icon(Icons.eco, size: 16, color: c.mint),
              const SizedBox(width: 6),
              Text('Optimized version',
                  style: TextStyle(
                      color: c.text, fontWeight: FontWeight.w600)),
              if (optimization!.calorieSavings != null) ...[
                const Spacer(),
                Text(
                  '-${optimization!.calorieSavings!.toInt()} kcal',
                  style: TextStyle(
                      color: c.mint,
                      fontWeight: FontWeight.w600,
                      fontSize: 13),
                ),
              ],
            ]),
            if (optimization!.portionNote != null) ...[
              const SizedBox(height: 6),
              Text(optimization!.portionNote!,
                  style: TextStyle(color: c.muted, fontSize: 13)),
            ],
            ...optimization!.suggestions
                .take(4)
                .map((s) => Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('→ ',
                              style: TextStyle(color: c.mint)),
                          Expanded(
                            child: Text(s.text,
                                style: TextStyle(
                                    color: c.text, fontSize: 13)),
                          ),
                          if (s.caloriesDelta != null)
                            Text(
                              '${s.caloriesDelta! > 0 ? '+' : ''}${s.caloriesDelta!.toInt()}',
                              style: TextStyle(
                                  color: s.caloriesDelta! < 0
                                      ? c.mint
                                      : c.danger,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                        ],
                      ),
                    )),
          ],

          if (optimization == null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: isOptimizing ? null : onOptimize,
              icon: isOptimizing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.eco, size: 16),
              label: Text(
                  isOptimizing ? 'Optimizing…' : 'Suggest lighter version'),
              style: OutlinedButton.styleFrom(
                primary: c.mint,
                side: BorderSide(color: c.mint),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _confidenceColor(BuildContext context, String confidence) {
    final c = context.appColors;
    if (confidence == 'high') return c.mint;
    if (confidence == 'low') return c.danger;
    return c.sky;
  }
}
