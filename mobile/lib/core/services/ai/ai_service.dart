import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

import '../../models/app_settings.dart';
import 'meal_analysis.dart';

const _defaultServerUrl = 'https://mnmealtracker.netlify.app/.netlify/functions/analyze-meal';

const _analyzePrompt = '''You are a clinical nutritionist. Analyze the food from the image, description, or both.
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

class AiService {
  final Dio _dio = Dio(BaseOptions(connectTimeout: 30000, receiveTimeout: 60000));

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
      description: description,
    );

    return MealAnalysis.fromJson(_parseJson(rawText));
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

    return MealOptimization.fromJson(_parseJson(rawText));
  }

  Future<String> _callProvider({
    required AppSettings settings,
    required String mode,
    String? b64,
    String? mimeType,
    String description = '',
    Map<String, dynamic>? analysis,
  }) async {
    switch (settings.provider) {
      case 'server':
        return _callServer(
          settings: settings,
          mode: mode,
          b64: b64,
          mimeType: mimeType,
          description: description,
          analysis: analysis,
        );
      case 'anthropic':
        return _callAnthropic(
          apiKey: settings.anthropicKey ?? '',
          mode: mode,
          b64: b64,
          mimeType: mimeType,
          description: description,
          analysis: analysis,
        );
      case 'openai':
        return _callOpenAi(
          apiKey: settings.openaiKey ?? '',
          mode: mode,
          b64: b64,
          mimeType: mimeType,
          description: description,
          analysis: analysis,
        );
      default:
        throw Exception('Unknown provider: ${settings.provider}');
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
  }) async {
    final url = (settings.serverUrl?.isNotEmpty == true
            ? settings.serverUrl!
            : _defaultServerUrl)
        .trimRight();

    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (settings.serverToken?.isNotEmpty == true)
        'X-Meal-Tracker-Token': settings.serverToken!,
    };

    final body = <String, dynamic>{'mode': mode, 'desc': description};
    if (b64 != null && mimeType != null) {
      body['img'] = {'b64': b64, 'type': mimeType};
    }
    if (analysis != null) body['analysis'] = analysis;

    final response = await _dio.post<Map<String, dynamic>>(
      url,
      data: body,
      options: Options(headers: headers),
    );

    final text = (response.data?['text'] as String?) ?? '';
    if (text.isEmpty) throw Exception('Empty response from server.');
    return text;
  }

  // ── Anthropic ──────────────────────────────────────────────────────────────

  Future<String> _callAnthropic({
    required String apiKey,
    required String mode,
    String? b64,
    String? mimeType,
    String description = '',
    Map<String, dynamic>? analysis,
  }) async {
    if (apiKey.isEmpty) throw Exception('Anthropic API key is not set.');

    final prompt = mode == 'optimize'
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
    if (text == null || text.isEmpty) throw Exception('Empty response from Anthropic.');
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
  }) async {
    if (apiKey.isEmpty) throw Exception('OpenAI API key is not set.');

    final prompt = mode == 'optimize'
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
    if (text == null || text.isEmpty) throw Exception('Empty response from OpenAI.');
    return text;
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  String _mimeFromPath(String path) {
    final ext = path.split('.').last.toLowerCase();
    if (ext == 'png') return 'image/png';
    if (ext == 'webp') return 'image/webp';
    return 'image/jpeg';
  }

  Map<String, dynamic> _parseJson(String text) {
    // Strip markdown fences if the model wrapped the response
    var cleaned = text.trim();
    if (cleaned.startsWith('```')) {
      cleaned = cleaned
          .replaceFirst(RegExp(r'^```[a-z]*\n?'), '')
          .replaceFirst(RegExp(r'```$'), '')
          .trim();
    }
    return jsonDecode(cleaned) as Map<String, dynamic>;
  }
}
