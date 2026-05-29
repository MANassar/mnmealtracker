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
        anthropicKey: json['anthropicKey'] as String?,
        openaiKey: json['openaiKey'] as String?,
        serverToken: json['serverToken'] as String?,
        serverUrl: json['serverUrl'] as String?,
      );
}
