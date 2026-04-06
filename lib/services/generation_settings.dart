import 'package:shared_preferences/shared_preferences.dart';

class GenerationSettings {
  final double temperature;
  final double topP;
  final int topK;
  final double minP;
  final double repeatPenalty;
  final int maxTokens;

  const GenerationSettings({
    this.temperature = 0.7,
    this.topP = 0.9,
    this.topK = 40,
    this.minP = 0.05,
    this.repeatPenalty = 1.12,
    this.maxTokens = 180,
  });

  GenerationSettings copyWith({
    double? temperature,
    double? topP,
    int? topK,
    double? minP,
    double? repeatPenalty,
    int? maxTokens,
  }) {
    return GenerationSettings(
      temperature: temperature ?? this.temperature,
      topP: topP ?? this.topP,
      topK: topK ?? this.topK,
      minP: minP ?? this.minP,
      repeatPenalty: repeatPenalty ?? this.repeatPenalty,
      maxTokens: maxTokens ?? this.maxTokens,
    );
  }

  Map<String, dynamic> toJson() => {
        'temperature': temperature,
        'topP': topP,
        'topK': topK,
        'minP': minP,
        'repeatPenalty': repeatPenalty,
        'maxTokens': maxTokens,
      };

  factory GenerationSettings.fromJson(Map<String, dynamic> json) {
    return GenerationSettings(
      temperature: (json['temperature'] as num?)?.toDouble() ?? 0.7,
      topP: (json['topP'] as num?)?.toDouble() ?? 0.9,
      topK: (json['topK'] as int?) ?? 40,
      minP: (json['minP'] as num?)?.toDouble() ?? 0.05,
      repeatPenalty: (json['repeatPenalty'] as num?)?.toDouble() ?? 1.12,
      maxTokens: (json['maxTokens'] as int?) ?? 180,
    );
  }

  static const GenerationSettings balanced = GenerationSettings(
    temperature: 0.7,
    topP: 0.9,
    topK: 40,
    minP: 0.05,
    repeatPenalty: 1.12,
    maxTokens: 180,
  );

  static const GenerationSettings conservative = GenerationSettings(
    temperature: 0.4,
    topP: 0.85,
    topK: 30,
    minP: 0.1,
    repeatPenalty: 1.2,
    maxTokens: 140,
  );

  static const GenerationSettings creative = GenerationSettings(
    temperature: 0.95,
    topP: 0.95,
    topK: 50,
    minP: 0.02,
    repeatPenalty: 1.05,
    maxTokens: 220,
  );

  static const GenerationSettings precise = GenerationSettings(
    temperature: 0.3,
    topP: 0.8,
    topK: 25,
    minP: 0.15,
    repeatPenalty: 1.25,
    maxTokens: 160,
  );

  static const Map<String, GenerationSettings> presets = {
    'Conservative': conservative,
    'Balanced': balanced,
    'Creative': creative,
    'Precise': precise,
  };
}

class GenerationSettingsService {
  static final GenerationSettingsService _instance = GenerationSettingsService._();

  factory GenerationSettingsService() => _instance;

  GenerationSettingsService._();

  static const String _prefsKey = 'generation_settings_v1';
  GenerationSettings _current = GenerationSettings.balanced;

  GenerationSettings get current => _current;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString(_prefsKey);

    if (jsonStr != null) {
      try {
        final json = jsonStr.split(',').asMap().entries.fold<Map<String, dynamic>>({}, (map, entry) {
          final parts = entry.value.split('=');
          if (parts.length == 2) {
            map[parts[0]] = parts[1];
          }
          return map;
        });

        final decoded = <String, dynamic>{};
        decoded['temperature'] = double.tryParse(prefs.getString('${_prefsKey}_temp') ?? '0.7');
        decoded['topP'] = double.tryParse(prefs.getString('${_prefsKey}_topP') ?? '0.9');
        decoded['topK'] = int.tryParse(prefs.getString('${_prefsKey}_topK') ?? '40');
        decoded['minP'] = double.tryParse(prefs.getString('${_prefsKey}_minP') ?? '0.05');
        decoded['repeatPenalty'] = double.tryParse(prefs.getString('${_prefsKey}_repeatPenalty') ?? '1.12');
        decoded['maxTokens'] = int.tryParse(prefs.getString('${_prefsKey}_maxTokens') ?? '180');

        if (decoded.values.every((v) => v != null)) {
          _current = GenerationSettings.fromJson(decoded.cast());
        }
      } catch (_) {
        _current = GenerationSettings.balanced;
      }
    }
  }

  Future<void> save(GenerationSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    _current = settings;

    await Future.wait([
      prefs.setString('${_prefsKey}_temp', settings.temperature.toString()),
      prefs.setString('${_prefsKey}_topP', settings.topP.toString()),
      prefs.setString('${_prefsKey}_topK', settings.topK.toString()),
      prefs.setString('${_prefsKey}_minP', settings.minP.toString()),
      prefs.setString('${_prefsKey}_repeatPenalty', settings.repeatPenalty.toString()),
      prefs.setString('${_prefsKey}_maxTokens', settings.maxTokens.toString()),
    ]);
  }

  Future<void> resetToDefaults() async {
    await save(GenerationSettings.balanced);
  }

  Future<void> applyPreset(String presetName) async {
    final preset = GenerationSettings.presets[presetName];
    if (preset != null) {
      await save(preset);
    }
  }
}
