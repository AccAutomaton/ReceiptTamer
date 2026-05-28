import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/llm_backend.dart';

class LlmConfigService {
  static const String _configKey = 'llm.backend.config.v1';

  Future<LlmBackendConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_configKey);
    if (raw == null || raw.trim().isEmpty) {
      return const LlmBackendConfig();
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        return LlmBackendConfig.fromJson(
          decoded.map((key, value) => MapEntry(key.toString(), value)),
        );
      }
    } catch (_) {
      return const LlmBackendConfig();
    }
    return const LlmBackendConfig();
  }

  Future<void> save(LlmBackendConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_configKey, jsonEncode(config.toJson()));
  }
}
