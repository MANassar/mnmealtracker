class AppSettings {
  final String provider; // server | anthropic | openai
  final String theme; // auto | light | dark
  final String weightUnit; // kg | lbs
  final double? goalCalories;
  final double? goalProtein;
  final double? goalCarbs;
  final double? goalFat;
  final double? goalFiber;
  final double? goalWeight; // in kg
  final MacroProfile? macroProfile;
  final MacroRecommendation? macroRecommendation;
  final String? anthropicKey;
  final String? openaiKey;
  final String? serverToken;
  final String? serverUrl;

  const AppSettings({
    this.provider = 'server',
    this.theme = 'auto',
    this.weightUnit = 'kg',
    this.goalCalories,
    this.goalProtein,
    this.goalCarbs,
    this.goalFat,
    this.goalFiber,
    this.goalWeight,
    this.macroProfile,
    this.macroRecommendation,
    this.anthropicKey,
    this.openaiKey,
    this.serverToken,
    this.serverUrl,
  });

  AppSettings copyWith({
    String? provider,
    String? theme,
    String? weightUnit,
    double? goalCalories,
    double? goalProtein,
    double? goalCarbs,
    double? goalFat,
    double? goalFiber,
    double? goalWeight,
    MacroProfile? macroProfile,
    MacroRecommendation? macroRecommendation,
    String? anthropicKey,
    String? openaiKey,
    String? serverToken,
    String? serverUrl,
    bool clearGoalWeight = false,
  }) {
    return AppSettings(
      provider: provider ?? this.provider,
      theme: theme ?? this.theme,
      weightUnit: weightUnit ?? this.weightUnit,
      goalCalories: goalCalories ?? this.goalCalories,
      goalProtein: goalProtein ?? this.goalProtein,
      goalCarbs: goalCarbs ?? this.goalCarbs,
      goalFat: goalFat ?? this.goalFat,
      goalFiber: goalFiber ?? this.goalFiber,
      goalWeight: clearGoalWeight ? null : (goalWeight ?? this.goalWeight),
      macroProfile: macroProfile ?? this.macroProfile,
      macroRecommendation: macroRecommendation ?? this.macroRecommendation,
      anthropicKey: anthropicKey ?? this.anthropicKey,
      openaiKey: openaiKey ?? this.openaiKey,
      serverToken: serverToken ?? this.serverToken,
      serverUrl: serverUrl ?? this.serverUrl,
    );
  }

  Map<String, dynamic> toJson() => {
        'provider': provider,
        'theme': theme,
        'weightUnit': weightUnit,
        if (goalCalories != null) 'goalCalories': goalCalories,
        if (goalProtein != null) 'goalProtein': goalProtein,
        if (goalCarbs != null) 'goalCarbs': goalCarbs,
        if (goalFat != null) 'goalFat': goalFat,
        if (goalFiber != null) 'goalFiber': goalFiber,
        if (goalWeight != null) 'goalWeight': goalWeight,
        if (macroProfile != null) 'macroProfile': macroProfile!.toJson(),
        if (macroRecommendation != null)
          'macroRecommendation': macroRecommendation!.toJson(),
        if (anthropicKey != null) 'anthropicKey': anthropicKey,
        if (openaiKey != null) 'openaiKey': openaiKey,
        if (serverToken != null) 'serverToken': serverToken,
        if (serverUrl != null) 'serverUrl': serverUrl,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        provider: json['provider'] as String? ?? 'server',
        theme: json['theme'] as String? ?? 'auto',
        weightUnit: json['weightUnit'] as String? ?? 'kg',
        goalCalories: (json['goalCalories'] as num?)?.toDouble(),
        goalProtein: (json['goalProtein'] as num?)?.toDouble(),
        goalCarbs: (json['goalCarbs'] as num?)?.toDouble(),
        goalFat: (json['goalFat'] as num?)?.toDouble(),
        goalFiber: (json['goalFiber'] as num?)?.toDouble(),
        goalWeight: (json['goalWeight'] as num?)?.toDouble(),
        macroProfile: json['macroProfile'] is Map
            ? MacroProfile.fromJson(
                Map<String, dynamic>.from(json['macroProfile'] as Map),
              )
            : null,
        macroRecommendation: json['macroRecommendation'] is Map
            ? MacroRecommendation.fromJson(
                Map<String, dynamic>.from(json['macroRecommendation'] as Map),
              )
            : null,
        anthropicKey: json['anthropicKey'] as String?,
        openaiKey: json['openaiKey'] as String?,
        serverToken: json['serverToken'] as String?,
        serverUrl: json['serverUrl'] as String?,
      );
}

class MacroProfile {
  final String gender;
  final double? weight;
  final int? age;
  final String activityLevel;
  final String goal;
  final String? updatedAt;

  const MacroProfile({
    this.gender = '',
    this.weight,
    this.age,
    this.activityLevel = 'moderate',
    this.goal = 'maintain',
    this.updatedAt,
  });

  Map<String, dynamic> toJson() => {
        'gender': gender,
        if (weight != null) 'weight': weight,
        if (age != null) 'age': age,
        'activityLevel': activityLevel,
        'goal': goal,
        if (updatedAt != null) 'updatedAt': updatedAt,
      };

  factory MacroProfile.fromJson(Map<String, dynamic> json) => MacroProfile(
        gender: json['gender'] as String? ?? '',
        weight: (json['weight'] as num?)?.toDouble(),
        age: (json['age'] as num?)?.toInt(),
        activityLevel: json['activityLevel'] as String? ?? 'moderate',
        goal: json['goal'] as String? ?? 'maintain',
        updatedAt: json['updatedAt'] as String?,
      );
}

class MacroRecommendation {
  final double calories;
  final double protein;
  final double carbs;
  final double fat;
  final String? method;
  final String? explanation;
  final String? cautions;

  const MacroRecommendation({
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fat,
    this.method,
    this.explanation,
    this.cautions,
  });

  Map<String, dynamic> toJson() => {
        'calories': calories,
        'protein': protein,
        'carbs': carbs,
        'fat': fat,
        if (method != null) 'method': method,
        if (explanation != null) 'explanation': explanation,
        if (cautions != null) 'cautions': cautions,
      };

  factory MacroRecommendation.fromJson(Map<String, dynamic> json) =>
      MacroRecommendation(
        calories: (json['calories'] as num?)?.toDouble() ?? 1800,
        protein: (json['protein'] as num?)?.toDouble() ?? 150,
        carbs: (json['carbs'] as num?)?.toDouble() ?? 180,
        fat: (json['fat'] as num?)?.toDouble() ?? 60,
        method: json['method'] as String?,
        explanation: json['explanation'] as String?,
        cautions: json['cautions'] as String?,
      );
}
