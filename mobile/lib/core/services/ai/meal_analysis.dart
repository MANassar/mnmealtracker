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
    this.steps = const [],
  });

  factory CoachSuggestion.fromJson(Map<String, dynamic> json) =>
      CoachSuggestion(
        mealName: json['mealName'] as String? ?? 'Suggested meal',
        timing: json['timing'] as String? ?? '',
        why: json['why'] as String? ?? '',
        calories: (json['calories'] as num?)?.toDouble() ?? 0,
        protein: (json['protein'] as num?)?.toDouble() ?? 0,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 0,
        fat: (json['fat'] as num?)?.toDouble() ?? 0,
        fiber: (json['fiber'] as num?)?.toDouble() ?? 0,
        ingredients:
            (json['ingredients'] as List?)?.map((e) => e.toString()).toList() ??
                [],
        steps:
            (json['steps'] as List?)?.map((e) => e.toString()).toList() ?? [],
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
        summary: json['summary'] as String? ?? '',
        focus: json['focus'] as String? ?? '',
        caution: json['caution'] as String? ?? '',
        suggestions: (json['suggestions'] as List?)
                ?.whereType<Map>()
                .map((e) =>
                    CoachSuggestion.fromJson(Map<String, dynamic>.from(e)))
                .toList() ??
            [],
      );
}
