import 'package:shared_preferences/shared_preferences.dart';

/// Stores only user-facing disclosure choices. Model credentials and backend
/// configuration remain owned by [LlmConfigService].
class AiUseDisclosureService {
  static const _cloudConsentPrefix = 'cloud_upload_consent_v1_';

  Future<bool> hasCloudConsent(String host) async {
    final consentKey = _consentKeyForHost(host);
    if (consentKey == null) return false;
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(consentKey) ?? false;
  }

  Future<void> rememberCloudConsent(String host) async {
    final consentKey = _consentKeyForHost(host);
    if (consentKey == null) return;
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(consentKey, true);
  }

  String? _consentKeyForHost(String host) {
    final normalizedHost = host.trim().toLowerCase();
    if (normalizedHost.isEmpty) return null;
    return '$_cloudConsentPrefix$normalizedHost';
  }
}
