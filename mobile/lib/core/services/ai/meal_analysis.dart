class MealAnalysis {
  final String mealName;
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final double fiber;
  final List<String> ingredients;
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

  factory MealAnalysis.fromJson(Map<String, dynamic> json) => MealAnalysis(
        mealName: json['mealName'] as String? ?? 'Unknown meal',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        ingredients:
            (json['ingredients'] as List?)?.map((e) => e.toString()).toList() ??
                [],
        confidence: json['confidence'] as String?,
        portionNote: json['portionNote'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'mealName': mealName,
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        'fiber': fiber,
        'ingredients': ingredients,
        if (confidence != null) 'confidence': confidence,
        if (portionNote != null) 'portionNote': portionNote,
      };
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
