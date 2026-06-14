import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/app_settings.dart';
import 'meal_analysis.dart';

const _defaultServerUrl =
    'https://mnmealtracker.netlify.app/.netlify/functions/analyze-meal';
// TODO(release): Remove this Development branch fallback before shipping.
const _developmentServerUrl =
    'https://development--mnmealtracker.netlify.app/.netlify/functions/analyze-meal';
const _defaultServerToken = 'f60c9972646d37fe29b95d95806f103c551799183c90d388';

const _analyzePrompt =
    '''You are a clinical nutritionist. Analyze the food from the image, description, or both.
Return ONLY a raw JSON object — no markdown, no explanation:
{"mealName":"specific dish name","calories":450,"protein":32.5,"carbs":28.0,"fat":18.5,"fiber":4.2,"ingredients":["visible component with estimated quantity","second visible component with estimated quantity"],"confidence":"high|medium|low","portionNote":"brief estimation note listing the detected visible components and portion assumptions"}
Calories in kcal. Macros in grams. Do not underestimate portions.''';

String _analyzePromptWithDesc(String desc) =>
    'You are a clinical nutritionist. Analyze the food from the image, description, or both. User context: "$desc"\n'
    'Return ONLY a raw JSON object — no markdown, no explanation:\n'
    '{"mealName":"specific dish name","calories":450,"protein":32.5,"carbs":28.0,"fat":18.5,"fiber":4.2,"ingredients":["visible component with estimated quantity","second visible component with estimated quantity"],"confidence":"high|medium|low","portionNote":"brief estimation note listing the detected visible components and portion assumptions"}\n'
    'Calories in kcal. Macros in grams. Do not underestimate portions.';

String _optimizePrompt(Map<String, dynamic> analysis, String desc) =>
    'You are a clinical nutritionist. Create a lower-calorie version of this meal while keeping it recognizable and satisfying.\n'
    'Original user context: "${desc.isEmpty ? 'No extra context provided.' : desc}"\n'
    'Original analysis: ${jsonEncode(analysis)}\n'
    'Return ONLY a raw JSON object — no markdown, no explanation:\n'
    '{"mealName":"optimized dish name","calories":350,"protein":30.0,"carbs":24.0,"fat":12.0,"fiber":5.0,"ingredients":["optimized item with estimated quantity"],"confidence":"high|medium|low","portionNote":"brief note explaining the calorie-focused changes","suggestions":[{"text":"replace 2 tbsp mayonnaise with 2 tbsp Greek yogurt","caloriesDelta":-120,"proteinDelta":5.0,"carbsDelta":1.0,"fatDelta":-12.0,"fiberDelta":0.0}],"calorieSavings":100}\n'
    'Calories in kcal. Macros in grams. Keep protein high. Each suggestion must name the original item, the replacement, and specific quantities.';

String _targetsPrompt(MacroProfile profile) =>
    'You are a registered dietitian and exercise nutrition specialist. Estimate daily calorie and macro targets from this user profile:\n'
    '${jsonEncode(profile.toJson())}\n'
    'Return ONLY a raw JSON object — no markdown, no explanation:\n'
    '{"calories":2100,"protein":150,"carbs":230,"fat":70,"method":"brief formula and activity-factor summary","explanation":"2-4 short sentences explaining why these targets fit the profile","cautions":"brief safety note that this is AI-generated general guidance and can be wrong; consult a qualified professional for medical conditions, pregnancy, eating disorder history, or performance nutrition"}\n'
    'Calories in kcal. Macros in grams. Round calories to the nearest 25 and macros to whole grams.';

String _coachPrompt(Map<String, dynamic> context) =>
    'You are a practical nutrition coach. Use all available user context to suggest meals that fit this exact moment of the day.\n'
    'Context: ${jsonEncode(context)}\n'
    'Write directly to the person using friendly second-person language: say "you" and "your". Never refer to them as "the user" or "User".\n'
    'Prioritize the user targets, remaining calories/macros, current consumption, time of day, meal history patterns, user weight, country/location if present, and exercise/fitness data if present. If country or exercise data is missing, do not invent it.\n'
    'Suggest realistic meals for the next eating occasion, not a full generic meal plan. At least 1 suggestion should be the same as, or clearly inspired by, something in recentMeals when recentMeals is not empty; adjust portions or sides to better fit today. Avoid repeating meals listed in alreadySuggestedMeals unless there is a strong reason. Keep suggestions culturally flexible and easy to prepare or order. The 3 suggestions must vary meaningfully in calories and macro split: include one familiar option, one lighter/high-protein option, and one balanced or higher-carb option when the remaining targets allow it.\n'
    'For every suggestion, explain how the total calories and macros were obtained with ingredient-level estimates. The totals must approximately equal the ingredient breakdown.\n'
    'Return ONLY a raw JSON object — no markdown, no explanation:\n'
    '{"summary":"short read on today so far","focus":"what to prioritize for the next meal","suggestions":[{"mealName":"specific meal idea","timing":"breakfast|lunch|dinner|snack|post-workout|anytime","why":"1-2 short sentences tying it to remaining targets and time of day","calories":450,"protein":35,"carbs":45,"fat":12,"fiber":8,"ingredients":["specific item and portion","specific item and portion"],"nutritionBreakdown":["150g chicken breast: 248 kcal, 46g protein, 0g carbs, 5g fat, 0g fiber","150g cooked rice: 195 kcal, 4g protein, 43g carbs, 0g fat, 1g fiber"],"steps":["short prep or ordering instruction","optional second step"]}],"caution":"brief safety note that this is AI-generated general nutrition guidance and can be wrong; consult a qualified professional for medical conditions, pregnancy, eating disorder history, or performance nutrition"}\n'
    'Provide exactly 3 suggestions. Calories in kcal. Macros in grams. Round totals to whole numbers. Keep each suggestion within the remaining day when possible; if remaining calories are very low, vary portion sizes while staying practical.';

class AiService {
  final Dio _dio =
      Dio(BaseOptions(connectTimeout: 30000, receiveTimeout: 60000));

  Future<MealAnalysis> analyze({
    required AppSettings settings,
    File? imageFile,
    String description = '',
  }) async {
    if (imageFile == null && description.isEmpty) {
      throw Exception('Please provide an image, a description, or both.');
    }

    String? b64;
    String? mimeType;
    if (imageFile != null) {
      final bytes = await imageFile.readAsBytes();
      b64 = base64Encode(bytes);
      mimeType = _mimeFromPath(imageFile.path);
    }

    final rawText = await _callProvider(
      settings: settings,
      mode: 'analyze',
      b64: b64,
      mimeType: mimeType,
      description: _descriptionContext(description, hasImage: b64 != null),
    );

    try {
      return MealAnalysis.fromJson(_parseJson(rawText));
    } on FormatException {
      if (b64 == null && description.trim().isNotEmpty) {
        final retryText = await _callProvider(
          settings: settings,
          mode: 'analyze',
          description:
              'TEXT ONLY. There is no image attached. Analyze this food description and return only the requested raw JSON object: ${description.trim()}',
        );
        try {
          return MealAnalysis.fromJson(_parseJson(retryText));
        } on FormatException {
          // Fall through to the user-facing message below.
        }
      }
      throw const AiServiceException(
        'The AI response was not valid nutrition data. Try again, or add a more specific meal description.',
      );
    }
  }

  Future<MealOptimization> optimize({
    required AppSettings settings,
    required MealAnalysis analysis,
    String description = '',
  }) async {
    final rawText = await _callProvider(
      settings: settings,
      mode: 'optimize',
      analysis: analysis.toJson(),
      description: description,
    );

    try {
      return MealOptimization.fromJson(_parseJson(rawText));
    } on FormatException {
      throw const AiServiceException(
        'The AI response was not valid optimization data. Try again in a moment.',
      );
    }
  }

  Future<MacroRecommendation> chooseTargets({
    required AppSettings settings,
    required MacroProfile profile,
  }) async {
    final rawText = await _callProvider(
      settings: settings,
      mode: 'targets',
      profile: profile,
    );

    try {
      return MacroRecommendation.fromJson(_parseJson(rawText));
    } on FormatException {
      throw const AiServiceException(
        'The AI response was not valid target data. Try again in a moment.',
      );
    }
  }

  Future<CoachPlan> coach({
    required AppSettings settings,
    required Map<String, dynamic> context,
  }) async {
    try {
      final rawText = await _callProvider(
        settings: settings,
        mode: 'coach',
        coachContext: context,
      );
      return CoachPlan.fromJson(_parseJson(rawText));
    } on AiServiceException catch (e) {
      if (settings.provider == 'server' && _serverCoachFallback(e.message)) {
        return _localCoachPlan(context);
      }
      rethrow;
    } on DioError catch (e) {
      final message = _dioMessage(e, settings.provider);
      if (settings.provider == 'server' && _serverCoachFallback(message)) {
        return _localCoachPlan(context);
      }
      throw AiServiceException(message);
    } on FormatException {
      throw const AiServiceException(
        'The AI response was not valid coach data. Try again in a moment.',
      );
    } catch (e) {
      final message = e.toString();
      if (settings.provider == 'server' && _serverCoachFallback(message)) {
        return _localCoachPlan(context);
      }
      throw AiServiceException(_cleanExceptionText(message));
    }
  }

  Future<String> _callProvider({
    required AppSettings settings,
    required String mode,
    String? b64,
    String? mimeType,
    String description = '',
    Map<String, dynamic>? analysis,
    MacroProfile? profile,
    Map<String, dynamic>? coachContext,
  }) async {
    try {
      switch (settings.provider) {
        case 'server':
          return _callServer(
            settings: settings,
            mode: mode,
            b64: b64,
            mimeType: mimeType,
            description: description,
            analysis: analysis,
            profile: profile,
            coachContext: coachContext,
          );
        case 'anthropic':
          return _callAnthropic(
            apiKey: settings.anthropicKey ?? '',
            mode: mode,
            b64: b64,
            mimeType: mimeType,
            description: description,
            analysis: analysis,
            profile: profile,
            coachContext: coachContext,
          );
        case 'openai':
          return _callOpenAi(
            apiKey: settings.openaiKey ?? '',
            mode: mode,
            b64: b64,
            mimeType: mimeType,
            description: description,
            analysis: analysis,
            profile: profile,
            coachContext: coachContext,
          );
        default:
          throw AiServiceException('Unknown provider: ${settings.provider}');
      }
    } on DioError catch (e) {
      throw AiServiceException(_dioMessage(e, settings.provider));
    } on FormatException {
      throw const AiServiceException(
        'The AI response was not valid JSON. Try again, or add a more specific meal description.',
      );
    }
  }

  // ── Server (Netlify function) ───────────────────────────────────────────────

  Future<String> _callServer({
    required AppSettings settings,
    required String mode,
    String? b64,
    String? mimeType,
    String description = '',
    Map<String, dynamic>? analysis,
    MacroProfile? profile,
    Map<String, dynamic>? coachContext,
  }) async {
    final url = (settings.serverUrl?.isNotEmpty == true
            ? settings.serverUrl!
            : _defaultServerUrl)
        .trimRight();
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'X-Meal-Tracker-Token': settings.serverToken?.isNotEmpty == true
          ? settings.serverToken!
          : _defaultServerToken,
    };

    final body = <String, dynamic>{'mode': mode, 'desc': description};
    if (b64 != null && mimeType != null) {
      body['img'] = {'b64': b64, 'type': mimeType};
    }
    if (analysis != null) body['analysis'] = analysis;
    if (profile != null) body['profile'] = profile.toJson();
    if (coachContext != null) body['context'] = coachContext;

    try {
      return await _postServer(url: url, headers: headers, body: body);
    } on DioError {
      if (_shouldTryDevelopmentServer(settings, url)) {
        return _postServer(
          url: _developmentServerUrl,
          headers: headers,
          body: body,
        );
      }
      rethrow;
    } on Exception {
      if (_shouldTryDevelopmentServer(settings, url)) {
        return _postServer(
          url: _developmentServerUrl,
          headers: headers,
          body: body,
        );
      }
      rethrow;
    }
  }

  Future<String> _postServer({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> body,
  }) async {
    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(headers: headers),
    );

    final text = (response.data?['text'] as String?) ?? '';
    if (text.isEmpty) throw Exception('Empty response from server.');
    return text;
  }

  bool _shouldTryDevelopmentServer(AppSettings settings, String url) {
    if (settings.serverUrl?.isNotEmpty == true) return false;
    return url == _defaultServerUrl &&
        _developmentServerUrl != _defaultServerUrl;
  }

  // ── Anthropic ──────────────────────────────────────────────────────────────

  Future<String> _callAnthropic({
    required String apiKey,
    required String mode,
    String? b64,
    String? mimeType,
    String description = '',
    Map<String, dynamic>? analysis,
    MacroProfile? profile,
    Map<String, dynamic>? coachContext,
  }) async {
    if (apiKey.isEmpty) throw Exception('Anthropic API key is not set.');

    final prompt = mode == 'targets'
        ? _targetsPrompt(profile!)
        : mode == 'coach'
            ? _coachPrompt(coachContext!)
            : mode == 'optimize'
                ? _optimizePrompt(analysis!, description)
                : (description.isNotEmpty
                    ? _analyzePromptWithDesc(description)
                    : _analyzePrompt);

    final contentList = <Map<String, dynamic>>[];
    if (b64 != null && mimeType != null && mode == 'analyze') {
      contentList.add({
        'type': 'image',
        'source': {
          'type': 'base64',
          'media_type': mimeType,
          'data': b64,
        },
      });
    }
    contentList.add({'type': 'text', 'text': prompt});

    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.anthropic.com/v1/messages',
      data: {
        'model': 'claude-opus-4-7',
        'max_tokens': 1000,
        'messages': [
          {'role': 'user', 'content': contentList}
        ],
      },
      options: Options(headers: {
        'x-api-key': apiKey,
        'anthropic-version': '2023-06-01',
        'Content-Type': 'application/json',
      }),
    );

    final text = (response.data?['content'] as List?)
            ?.whereType<Map>()
            .firstWhere((c) => c['type'] == 'text', orElse: () => {})['text']
        as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from Anthropic.');
    }
    return text;
  }

  // ── OpenAI ─────────────────────────────────────────────────────────────────

  Future<String> _callOpenAi({
    required String apiKey,
    required String mode,
    String? b64,
    String? mimeType,
    String description = '',
    Map<String, dynamic>? analysis,
    MacroProfile? profile,
    Map<String, dynamic>? coachContext,
  }) async {
    if (apiKey.isEmpty) throw Exception('OpenAI API key is not set.');

    final prompt = mode == 'targets'
        ? _targetsPrompt(profile!)
        : mode == 'coach'
            ? _coachPrompt(coachContext!)
            : mode == 'optimize'
                ? _optimizePrompt(analysis!, description)
                : (description.isNotEmpty
                    ? _analyzePromptWithDesc(description)
                    : _analyzePrompt);

    final contentList = <Map<String, dynamic>>[];
    if (b64 != null && mimeType != null && mode == 'analyze') {
      contentList.add({
        'type': 'image_url',
        'image_url': {'url': 'data:$mimeType;base64,$b64'},
      });
    }
    contentList.add({'type': 'text', 'text': prompt});

    final response = await _dio.post<Map<String, dynamic>>(
      'https://api.openai.com/v1/chat/completions',
      data: {
        'model': 'gpt-4o',
        'max_tokens': 1000,
        'messages': [
          {'role': 'user', 'content': contentList}
        ],
      },
      options: Options(headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
      }),
    );

    final text = (response.data?['choices'] as List?)
        ?.whereType<Map>()
        .first['message']?['content'] as String?;
    if (text == null || text.isEmpty) {
      throw Exception('Empty response from OpenAI.');
    }
    return text;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  String _descriptionContext(String description, {required bool hasImage}) {
    final trimmed = description.trim();
    if (trimmed.isEmpty || hasImage) return trimmed;
    return 'Text-only food description; no image is attached: $trimmed';
  }

  Map<String, dynamic> _parseJson(String text) {
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();
    }

    try {
      final direct = jsonDecode(cleaned);
      if (direct is Map<String, dynamic>) return direct;
    } on FormatException {
      // Some models still add a short sentence before the object. If a JSON
      // object is present, recover it instead of failing the whole analysis.
    }

    final start = cleaned.indexOf('{');
    final end = cleaned.lastIndexOf('}');
    if (start >= 0 && end > start) {
      final extracted = jsonDecode(cleaned.substring(start, end + 1));
      if (extracted is Map<String, dynamic>) return extracted;
    }

    throw const FormatException('AI response was not a JSON object.');
  }

  String _dioMessage(DioError error, String provider) {
    final statusCode = error.response?.statusCode;
    final detail = _responseMessage(error.response?.data);

    if (statusCode == 401) {
      if (provider == 'server') {
        return 'The meal analysis server rejected the request. Add or update the server token in Settings, or switch to OpenAI/Anthropic with your own API key.';
      }
      return '${_providerName(provider)} rejected the API key. Check the key in Settings and try again.';
    }

    if (statusCode == 403) {
      return '${_providerName(provider)} refused this request. Check your API key permissions or server token.';
    }

    if (statusCode == 429) {
      return '${_providerName(provider)} is rate limiting requests. Wait a moment and try again.';
    }

    if (statusCode != null && statusCode >= 500) {
      return '${_providerName(provider)} is temporarily unavailable. Try again in a moment.';
    }

    switch (error.type) {
      case DioErrorType.connectTimeout:
      case DioErrorType.sendTimeout:
      case DioErrorType.receiveTimeout:
        return 'The meal analysis request timed out. Check your connection and try again.';
      case DioErrorType.cancel:
        return 'The meal analysis request was cancelled.';
      case DioErrorType.response:
        return detail == null
            ? 'Meal analysis failed with HTTP status ${statusCode ?? 'unknown'}.'
            : 'Meal analysis failed: $detail';
      case DioErrorType.other:
        return 'Could not reach ${_providerName(provider)}. Check your connection and try again.';
    }
  }

  String? _responseMessage(dynamic data) {
    if (data is Map) {
      final value = data['error'] ?? data['message'] ?? data['detail'];
      if (value != null) return value.toString();
    }
    if (data is String && data.trim().isNotEmpty) return data.trim();
    return null;
  }

  String _providerName(String provider) {
    switch (provider) {
      case 'server':
        return 'the meal analysis server';
      case 'anthropic':
        return 'Anthropic';
      case 'openai':
        return 'OpenAI';
      default:
        return provider;
    }
  }

  bool _serverCoachFallback(String message) {
    final lower = message.toLowerCase();
    return lower.contains('400') ||
        lower.contains('please provide an image') ||
        lower.contains('coach context') ||
        lower.contains('not valid coach');
  }

  CoachPlan _localCoachPlan(Map<String, dynamic> context) {
    final remaining =
        Map<String, dynamic>.from(context['remainingToday'] as Map? ?? {});
    final targets = Map<String, dynamic>.from(context['targets'] as Map? ?? {});
    final time = Map<String, dynamic>.from(context['localTime'] as Map? ?? {});
    final hour = (time['hour'] as num?)?.toInt() ?? DateTime.now().hour;
    final mealSlot = hour < 11
        ? 'breakfast'
        : hour < 15
            ? 'lunch'
            : hour < 18
                ? 'snack'
                : 'dinner';
    final caloriesLeft =
        _num(remaining['calories'], _num(targets['calories'], 1800));
    final light = caloriesLeft <= 300;
    final alreadySuggested =
        (context['alreadySuggestedMeals'] as List?)?.length ?? 0;
    final recentMeal = _recentMealSuggestion(context, mealSlot);

    return CoachPlan(
      summary:
          'The coach server is not ready for this app build yet, so this is a local suggestion based on your remaining targets.',
      focus: caloriesLeft <= 300
          ? 'Keep the next choice small, protein-forward, and easy on added fats.'
          : 'Prioritize protein first, then use carbs or fats to fit the rest of your day.',
      caution:
          'AI coach mode will take over after the server function with coach support is deployed. This is general nutrition guidance and can be wrong.',
      suggestions: alreadySuggested >= 3
          ? [
              CoachSuggestion(
                mealName: 'Cottage cheese fruit plate',
                timing: mealSlot,
                why:
                    'A lighter protein-first option with modest carbs from fruit.',
                calories: 320,
                protein: 34,
                carbs: 32,
                fat: 6,
                fiber: 5,
                ingredients: const [
                  '250g cottage cheese',
                  '1 medium apple or pear',
                  '10g chia seeds',
                ],
                nutritionBreakdown: const [
                  '250g cottage cheese: 210 kcal, 31g protein, 10g carbs, 5g fat, 0g fiber',
                  '1 medium apple or pear: 95 kcal, 1g protein, 25g carbs, 0g fat, 4g fiber',
                  '10g chia seeds: 50 kcal, 2g protein, 4g carbs, 3g fat, 4g fiber',
                ],
                steps: const [
                  'Use berries instead of apple if you need fewer carbs.',
                ],
              ),
              CoachSuggestion(
                mealName: 'Tofu noodle stir-fry',
                timing: mealSlot,
                why:
                    'Balanced protein, carbs, and fats with more volume from vegetables.',
                calories: 520,
                protein: 32,
                carbs: 62,
                fat: 16,
                fiber: 9,
                ingredients: const [
                  '180g firm tofu',
                  '180g cooked noodles',
                  '2 cups stir-fry vegetables',
                  '1 tbsp teriyaki or soy-based sauce',
                ],
                nutritionBreakdown: const [
                  '180g firm tofu: 210 kcal, 23g protein, 5g carbs, 12g fat, 2g fiber',
                  '180g cooked noodles: 230 kcal, 7g protein, 48g carbs, 1g fat, 3g fiber',
                  '2 cups stir-fry vegetables: 70 kcal, 4g protein, 14g carbs, 0g fat, 4g fiber',
                  '1 tbsp sauce: 25 kcal, 1g protein, 5g carbs, 0g fat, 0g fiber',
                ],
                steps: const [
                  'Use half the noodles if calories are tight.',
                ],
              ),
              CoachSuggestion(
                mealName: 'Turkey avocado sandwich',
                timing: mealSlot,
                why:
                    'A more filling option with higher carbs and fats for a larger remaining window.',
                calories: 610,
                protein: 44,
                carbs: 58,
                fat: 22,
                fiber: 10,
                ingredients: const [
                  '2 slices whole-grain bread',
                  '150g sliced turkey breast',
                  '50g avocado',
                  'Salad vegetables',
                ],
                nutritionBreakdown: const [
                  '2 slices whole-grain bread: 220 kcal, 10g protein, 38g carbs, 4g fat, 6g fiber',
                  '150g sliced turkey breast: 180 kcal, 36g protein, 2g carbs, 3g fat, 0g fiber',
                  '50g avocado: 80 kcal, 1g protein, 4g carbs, 7g fat, 3g fiber',
                  'Salad vegetables and light spread: 70 kcal, 2g protein, 8g carbs, 4g fat, 1g fiber',
                ],
                steps: const [
                  'Skip avocado or use one bread slice if you need a smaller meal.',
                ],
              ),
            ]
          : [
              if (recentMeal != null) recentMeal,
              CoachSuggestion(
                mealName: caloriesLeft <= 300
                    ? 'Greek yogurt protein bowl'
                    : 'Chicken rice power bowl',
                timing: mealSlot,
                why:
                    'Fits the current calorie window while pushing protein toward your daily target.',
                calories: light ? 245 : 588,
                protein: light ? 28 : 54,
                carbs: light ? 19 : 56,
                fat: light ? 6 : 14,
                fiber: light ? 4 : 8,
                ingredients: light
                    ? const [
                        '250g Greek yogurt or skyr',
                        '1 small serving berries',
                        '10g nuts or seeds',
                      ]
                    : const [
                        '150g grilled chicken breast',
                        '150g cooked rice or potatoes',
                        '2 cups vegetables',
                        '1 tbsp olive oil or light sauce',
                      ],
                nutritionBreakdown: light
                    ? const [
                        '250g Greek yogurt or skyr: 150 kcal, 25g protein, 9g carbs, 1g fat, 0g fiber',
                        '75g berries: 35 kcal, 1g protein, 8g carbs, 0g fat, 3g fiber',
                        '10g nuts or seeds: 60 kcal, 2g protein, 2g carbs, 5g fat, 1g fiber',
                      ]
                    : const [
                        '150g grilled chicken breast: 248 kcal, 46g protein, 0g carbs, 5g fat, 0g fiber',
                        '150g cooked rice or potatoes: 180 kcal, 4g protein, 40g carbs, 0g fat, 2g fiber',
                        '2 cups vegetables: 70 kcal, 4g protein, 14g carbs, 0g fat, 6g fiber',
                        '1 tbsp olive oil or light sauce: 90 kcal, 0g protein, 2g carbs, 9g fat, 0g fiber',
                      ],
                steps: const [
                  'Adjust the carb portion up or down to match your remaining calories.',
                ],
              ),
              CoachSuggestion(
                mealName: 'Tuna and egg salad plate',
                timing: mealSlot,
                why:
                    'A high-protein option that stays flexible if you are short on calories or carbs.',
                calories: 410,
                protein: 51,
                carbs: 17,
                fat: 14,
                fiber: 6,
                ingredients: const [
                  '1 can tuna or salmon',
                  '2 boiled eggs',
                  'Large salad vegetables',
                  'Light dressing or yogurt sauce',
                ],
                nutritionBreakdown: const [
                  '1 can tuna or salmon: 150 kcal, 32g protein, 0g carbs, 2g fat, 0g fiber',
                  '2 boiled eggs: 140 kcal, 12g protein, 1g carbs, 10g fat, 0g fiber',
                  'Large salad vegetables: 70 kcal, 4g protein, 12g carbs, 0g fat, 5g fiber',
                  'Light dressing or yogurt sauce: 50 kcal, 3g protein, 4g carbs, 2g fat, 1g fiber',
                ],
                steps: const [
                  'Add bread, rice cakes, or fruit only if carbs remain.'
                ],
              ),
              CoachSuggestion(
                mealName: 'Lean protein wrap',
                timing: mealSlot,
                why:
                    'Easy to prepare or order, with controlled portions and a balanced macro profile.',
                calories: 425,
                protein: 39,
                carbs: 46,
                fat: 10,
                fiber: 8,
                ingredients: const [
                  '1 whole-grain wrap',
                  '120g lean turkey, chicken, tofu, or beans',
                  'Crunchy vegetables',
                  'Low-fat yogurt sauce or salsa',
                ],
                nutritionBreakdown: const [
                  '1 whole-grain wrap: 180 kcal, 6g protein, 30g carbs, 4g fat, 4g fiber',
                  '120g lean turkey, chicken, tofu, or beans: 170 kcal, 28g protein, 4g carbs, 5g fat, 1g fiber',
                  'Crunchy vegetables: 40 kcal, 2g protein, 8g carbs, 0g fat, 3g fiber',
                  'Low-fat yogurt sauce or salsa: 35 kcal, 3g protein, 4g carbs, 1g fat, 0g fiber',
                ],
                steps: const [
                  'Skip cheese or heavy sauces if fat is nearly used up.'
                ],
              ),
            ],
    );
  }

  CoachSuggestion? _recentMealSuggestion(
    Map<String, dynamic> context,
    String mealSlot,
  ) {
    final recentMeals = context['recentMeals'];
    if (recentMeals is! List || recentMeals.isEmpty) return null;
    Map? raw;
    for (final item in recentMeals) {
      if (item is Map) {
        raw = item;
        break;
      }
    }
    if (raw == null) return null;
    final name = raw['mealName']?.toString().trim();
    if (name == null || name.isEmpty) return null;
    final calories = _num(raw['calories'], 450).clamp(180, 750).toDouble();
    final protein = _num(raw['protein'], 30).clamp(5, 70).toDouble();
    final carbs = _num(raw['carbs'], 40).clamp(0, 100).toDouble();
    final fat = _num(raw['fat'], 15).clamp(0, 45).toDouble();
    final fiber = _num(raw['fiber'], 5).clamp(0, 20).toDouble();
    final ingredients = (raw['ingredients'] as List?)
            ?.map((e) => e.toString())
            .where((e) => e.trim().isNotEmpty)
            .take(4)
            .toList() ??
        const <String>[];

    return CoachSuggestion(
      mealName: '$name, adjusted for today',
      timing: mealSlot,
      why:
          'This is close to something you already eat, with portions you can tweak to fit the rest of today.',
      calories: calories,
      protein: protein,
      carbs: carbs,
      fat: fat,
      fiber: fiber,
      ingredients:
          ingredients.isEmpty ? ['A familiar portion of $name'] : ingredients,
      nutritionBreakdown: [
        '$name based on your recent log: ${calories.round()} kcal, ${protein.round()}g protein, ${carbs.round()}g carbs, ${fat.round()}g fat, ${fiber.round()}g fiber',
      ],
      steps: const [
        'Keep the familiar base, then reduce or add the carb/fat side depending on your remaining targets.',
      ],
    );
  }

  double _num(dynamic value, double fallback) {
    if (value is num && value.isFinite) return value.toDouble();
    return fallback;
  }

  String _cleanExceptionText(String text) {
    final cleaned = text
        .replaceFirst('Exception: ', '')
        .replaceFirst(RegExp(r'Source stack:[\s\S]*'), '')
        .trim();
    return cleaned.isEmpty
        ? 'The request failed. Try again in a moment.'
        : cleaned;
  }
}

class AiServiceException implements Exception {
  final String message;

  const AiServiceException(this.message);

  @override
  String toString() => message;
}
