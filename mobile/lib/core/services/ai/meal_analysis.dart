class MealIngredient {
  final String name;
  final String? quantity;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;

  const MealIngredient({
    required this.name,
    this.quantity,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
  });

  factory MealIngredient.fromJson(Object? value) {
    if (value is Map) {
      final json = Map<String, dynamic>.from(value);
      final nutrition = _nestedMap(json, 'nutrition') ??
          _nestedMap(json, 'macros') ??
          _nestedMap(json, 'nutritionBreakdown');
      final text = (json['text'] ??
              json['description'] ??
              json['label'] ??
              json['name'] ??
              json['ingredient'] ??
              json['item'] ??
              '')
          .toString()
          .trim();
      final parsedText = _fromText(text);
      return MealIngredient(
        name: (json['name'] ??
                json['ingredient'] ??
                json['item'] ??
                parsedText.name)
            .toString()
            .trim(),
        quantity: (json['quantity'] ?? json['portion'] ?? json['amount'])
                ?.toString()
                .trim()
                .replaceAll(RegExp(r'\s+'), ' ') ??
            parsedText.quantity,
        calories: _num(json, nutrition, const [
              'calories',
              'caloriesKcal',
              'calories_kcal',
              'kcal',
              'energy',
              'energyKcal',
              'energy_kcal',
            ]) ??
            parsedText.calories,
        protein: _num(json, nutrition, const [
              'protein',
              'proteinG',
              'protein_g',
              'proteinGrams',
              'protein_grams',
            ]) ??
            parsedText.protein,
        carbs: _num(json, nutrition, const [
              'carbs',
              'carbohydrates',
              'carbohydrate',
              'carbsG',
              'carbs_g',
              'carbohydratesG',
              'carbohydrates_g',
            ]) ??
            parsedText.carbs,
        fat: _num(json, nutrition, const [
              'fat',
              'fats',
              'fatG',
              'fat_g',
              'fatGrams',
              'fat_grams',
            ]) ??
            parsedText.fat,
        fiber: _num(json, nutrition, const [
              'fiber',
              'fibre',
              'fiberG',
              'fiber_g',
              'fibreG',
              'fibre_g',
            ]) ??
            parsedText.fiber,
      );
    }

    final text = value?.toString().trim() ?? '';
    return _fromText(text);
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (quantity != null && quantity!.isNotEmpty) 'quantity': quantity,
        if (calories != null) 'calories': calories,
        if (protein != null) 'protein': protein,
        if (carbs != null) 'carbs': carbs,
        if (fat != null) 'fat': fat,
        if (fiber != null) 'fiber': fiber,
      };

  String get label {
    final q = quantity?.trim();
    return q == null || q.isEmpty ? name : '$q $name';
  }

  bool get hasNutrition =>
      calories != null ||
      protein != null ||
      carbs != null ||
      fat != null ||
      fiber != null;

  static Map<String, dynamic>? _nestedMap(
    Map<String, dynamic> json,
    String key,
  ) {
    final value = json[key];
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }

  static double? _num(
    Map<String, dynamic> json,
    Map<String, dynamic>? nested,
    List<String> keys,
  ) {
    for (final source in [json, if (nested != null) nested]) {
      for (final key in keys) {
        final value = source[key];
        if (value is num) return value.toDouble();
        if (value is String) {
          final match = RegExp(r'-?\d+(?:\.\d+)?').firstMatch(value);
          if (match != null) return double.tryParse(match.group(0)!);
        }
      }
    }
    return null;
  }

  static MealIngredient _fromText(String text) {
    final label = text.trim();
    if (label.isEmpty) return const MealIngredient(name: '');

    final beforeColon = label.split(RegExp(r':|\s[-–—]\s')).first.trim();
    final name = beforeColon.isEmpty ? label : beforeColon;
    return MealIngredient(
      name: name,
      calories: _textNumber(label, RegExp(r'(\d+(?:\.\d+)?)\s*(?:kcal|cal)')),
      protein: _textNumberAny(label, [
        RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*(?:protein|p\b)', caseSensitive: false),
        RegExp(r'(?:protein|p\b)\s*:?\s*(\d+(?:\.\d+)?)', caseSensitive: false),
      ]),
      carbs: _textNumberAny(label, [
        RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*(?:carbs?|carbohydrates?|c\b)',
            caseSensitive: false),
        RegExp(r'(?:carbs?|carbohydrates?|c\b)\s*:?\s*(\d+(?:\.\d+)?)',
            caseSensitive: false),
      ]),
      fat: _textNumberAny(label, [
        RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*(?:fat|f\b)', caseSensitive: false),
        RegExp(r'(?:fat|f\b)\s*:?\s*(\d+(?:\.\d+)?)', caseSensitive: false),
      ]),
      fiber: _textNumberAny(label, [
        RegExp(r'(\d+(?:\.\d+)?)\s*g?\s*(?:fib(?:er|re)?|fi\b)',
            caseSensitive: false),
        RegExp(r'(?:fib(?:er|re)?|fi\b)\s*:?\s*(\d+(?:\.\d+)?)',
            caseSensitive: false),
      ]),
    );
  }

  static double? _textNumber(String text, RegExp pattern) {
    final match = pattern.firstMatch(text);
    return match == null ? null : double.tryParse(match.group(1)!);
  }

  static double? _textNumberAny(String text, List<RegExp> patterns) {
    for (final pattern in patterns) {
      final value = _textNumber(text, pattern);
      if (value != null) return value;
    }
    return null;
  }
}

String? _cleanPortionNote(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return trimmed;
  return trimmed.replaceAll(
    RegExp(r'estimated based on typical servings?', caseSensitive: false),
    'estimated from provided details where available; unspecified amounts were inferred',
  );
}

List<MealIngredient> _ingredientList(Object? value) {
  if (value is! List) return const [];
  return value
      .map(MealIngredient.fromJson)
      .where((e) => e.name.isNotEmpty)
      .toList();
}

List<MealIngredient> _analysisIngredients(Map<String, dynamic> json) {
  final ingredients = _ingredientList(json['ingredients']);
  final breakdown = _ingredientList(
    json['nutritionBreakdown'] ??
        json['ingredientBreakdown'] ??
        json['macroBreakdown'] ??
        json['ingredientNutrition'],
  );

  if (ingredients.isEmpty) return breakdown;
  if (ingredients.any((item) => item.hasNutrition)) return ingredients;
  if (breakdown.any((item) => item.hasNutrition)) return breakdown;
  return ingredients;
}

class MealAnalysis {
  final String mealName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final List<MealIngredient> ingredients;
  final String? confidence;
  final String? portionNote;

  const MealAnalysis({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.ingredients = const [],
    this.confidence,
    this.portionNote,
  });

  factory MealAnalysis.fromJson(Map<String, dynamic> json) {
    final ingredients = _analysisIngredients(json);
    return MealAnalysis(
      mealName: json['mealName'] as String? ?? 'Unknown meal',
      calories: (json['calories'] as num?)?.toDouble() ?? 0,
      protein: (json['protein'] as num?)?.toDouble() ?? 0,
      carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
      fat: (json['fat'] as num?)?.toDouble() ?? 0,
      fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
      ingredients: ingredients,
      confidence: json['confidence'] as String?,
      portionNote: _cleanPortionNote(json['portionNote'] as String?),
    );
  }

  Map<String, dynamic> toJson() => {
        'mealName': mealName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'ingredients': ingredients.map((e) => e.toJson()).toList(),
        if (confidence != null) 'confidence': confidence,
        if (portionNote != null) 'portionNote': portionNote,
      };

  bool get needsIngredientNutrition =>
      ingredients.isNotEmpty && ingredients.any((item) => !item.hasNutrition);
}

class MealOptimization {
  final String mealName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final String? portionNote;
  final double? calorieSavings;
  final List<OptimizationSuggestion> suggestions;

  const MealOptimization({
    required this.mealName,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.portionNote,
    this.calorieSavings,
    this.suggestions = const [],
  });

  factory MealOptimization.fromJson(Map<String, dynamic> json) =>
      MealOptimization(
        mealName: json['mealName'] as String? ?? 'Optimized meal',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        portionNote: json['portionNote'] as String?,
        calorieSavings: (json['calorieSavings'] as num?)?.toDouble(),
        suggestions: (json['suggestions'] as List?)
                ?.map((e) =>
                    OptimizationSuggestion.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
      );
}

class OptimizationSuggestion {
  final String text;
  final double? caloriesDelta;
  final double? proteinDelta;
  final double? carbsDelta;
  final double? fatDelta;
  final double? fiberDelta;

  const OptimizationSuggestion({
    required this.text,
    this.caloriesDelta,
    this.proteinDelta,
    this.carbsDelta,
    this.fatDelta,
    this.fiberDelta,
  });

  factory OptimizationSuggestion.fromJson(Map<String, dynamic> json) =>
      OptimizationSuggestion(
        text: json['text'] as String? ?? '',
        caloriesDelta: (json['caloriesDelta'] as num?)?.toDouble(),
        proteinDelta: (json['proteinDelta'] as num?)?.toDouble(),
        carbsDelta: (json['carbsDelta'] as num?)?.toDouble(),
        fatDelta: (json['fatDelta'] as num?)?.toDouble(),
        fiberDelta: (json['fiberDelta'] as num?)?.toDouble(),
      );
}

class CoachSuggestion {
  final String mealName;
  final String timing;
  final String why;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final List<String> ingredients;
  final List<String> nutritionBreakdown;
  final List<String> steps;

  const CoachSuggestion({
    required this.mealName,
    required this.timing,
    required this.why,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    required this.fiber,
    this.ingredients = const [],
    this.nutritionBreakdown = const [],
    this.steps = const [],
  });

  factory CoachSuggestion.fromJson(Map<String, dynamic> json) =>
      CoachSuggestion(
        mealName: _coachCopy(json['mealName'] as String? ?? 'Suggested meal'),
        timing: _coachCopy(json['timing'] as String? ?? ''),
        why: _coachCopy(json['why'] as String? ?? ''),
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        ingredients: (json['ingredients'] as List?)
                ?.map((e) => _coachCopy(e.toString()))
                .toList() ??
            [],
        nutritionBreakdown: (json['nutritionBreakdown'] as List?)
                ?.map((e) => _coachCopy(e.toString()))
                .toList() ??
            [],
        steps: (json['steps'] as List?)
                ?.map((e) => _coachCopy(e.toString()))
                .toList() ??
            [],
      );
}

class CoachPlan {
  final String summary;
  final String focus;
  final String caution;
  final List<CoachSuggestion> suggestions;

  const CoachPlan({
    required this.summary,
    required this.focus,
    required this.caution,
    this.suggestions = const [],
  });

  factory CoachPlan.fromJson(Map<String, dynamic> json) => CoachPlan(
        summary: _coachCopy(json['summary'] as String? ?? ''),
        focus: _coachCopy(json['focus'] as String? ?? ''),
        caution: _coachCopy(json['caution'] as String? ?? ''),
        suggestions: (json['suggestions'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    CoachSuggestion.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}

String _coachCopy(String value) {
  return value
      .replaceAll(RegExp(r'\b[Tt]he user has\b'), 'You have')
      .replaceAll(RegExp(r'\b[Tt]he user is\b'), 'You are')
      .replaceAll(RegExp(r'\b[Tt]he user should\b'), 'You should')
      .replaceAll(RegExp(r'\b[Tt]he user needs\b'), 'You need')
      .replaceAll(RegExp(r'\b[Tt]he user\b'), 'you')
      .replaceAll(RegExp(r'\bUser has\b'), 'You have')
      .replaceAll(RegExp(r'\bUser is\b'), 'You are')
      .replaceAll(RegExp(r'\bUser should\b'), 'You should')
      .replaceAll(RegExp(r'\bUser needs\b'), 'You need')
      .replaceAll(RegExp(r'\bUser\b'), 'You');
}
