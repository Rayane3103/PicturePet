import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Configuration for accessing the fal.ai APIs.
class FalConfig {
  // API key from --dart-define or .env (FAL_API_KEY)
  static const String _apiKeyDefine = String.fromEnvironment('FAL_API_KEY', defaultValue: '');
  static String get _apiKeyDotenv {
    try {
      // ignore: avoid_dynamic_calls
      return (dotenv.env['FAL_API_KEY'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  static String get apiKey {
    if (_apiKeyDefine.isNotEmpty) return _apiKeyDefine;
    if (_apiKeyDotenv.isNotEmpty) return _apiKeyDotenv;
    return '';
  }

  // Base URL (optional override), defaults to public fal.run
  static const String _baseUrlDefine = String.fromEnvironment('FAL_BASE_URL', defaultValue: '');
  static String get _baseUrlDotenv {
    try {
      // ignore: avoid_dynamic_calls
      return (dotenv.env['FAL_BASE_URL'] ?? '').toString();
    } catch (_) {
      return '';
    }
  }

  static String get baseUrl {
    if (_baseUrlDefine.isNotEmpty) return _baseUrlDefine;
    if (_baseUrlDotenv.isNotEmpty) return _baseUrlDotenv;
    return 'https://fal.run';
  }

  // REST model paths
  static const String modelNanoBananaEditPath = 'fal-ai/nano-banana/edit';
}


