import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../config/fal_config.dart';

/// Minimal fal.ai client for the app. Only implements nano-banana edit.
class FalAiService {
  FalAiService({http.Client? httpClient})
      : _client = httpClient ?? http.Client();

  final http.Client _client;

  /// Calls fal-ai/nano-banana/edit with a single input image and prompt.
  /// Returns the generated image bytes.
  ///
  /// This uses REST via fal.run; all optional params are omitted to use defaults.
  Future<Uint8List> nanoBananaEdit({
    required Uint8List inputImageBytes,
    required String prompt,
  }) async {
    final String apiKey = FalConfig.apiKey;
    if (apiKey.isEmpty) {
      throw Exception(
          'FAL_API_KEY is missing. Please configure it securely via server-side proxy');
    }

    // Build data URL for the input image. Try to sniff type from header bytes; fallback to jpeg.
    final String mime = _detectMimeType(inputImageBytes);
    final String dataUrl = 'data:$mime;base64,${base64Encode(inputImageBytes)}';

    final Uri uri = Uri.parse('${FalConfig.baseUrl}/${FalConfig.modelNanoBananaEditPath}');

    final Map<String, String> headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Key $apiKey',
    };

    // Only required inputs: prompt and image(s). The model expects one image.
    // Some fal models accept image_urls array; others accept image. We support both fields
    // to maximize compatibility; the backend will read whichever is supported.
    final Map<String, dynamic> body = <String, dynamic>{
      'input': <String, dynamic>{
        'prompt': prompt,
        'image_urls': <String>[dataUrl],
        'image': dataUrl,
      },
    };

    final http.Response resp = await _client.post(
      uri,
      headers: headers,
      body: jsonEncode(body),
    );

    if (resp.statusCode < 200 || resp.statusCode >= 300) {
      throw Exception('fal.ai error ${resp.statusCode}: ${resp.body}');
    }

    final Map<String, dynamic> json =
        jsonDecode(resp.body) as Map<String, dynamic>;

    // nano-banana response shape: { images: [ { url: ... } ] }
    final dynamic images = json['images'];
    if (images is List && images.isNotEmpty) {
      final dynamic first = images.first;
      if (first is Map<String, dynamic>) {
        final String? url = first['url'] as String?;
        if (url != null && url.isNotEmpty) {
          final http.Response imgResp = await _client.get(Uri.parse(url));
          if (imgResp.statusCode == 200) {
            return imgResp.bodyBytes;
          }
          throw Exception(
              'Failed to fetch generated image: HTTP ${imgResp.statusCode}');
        }
      }
    }
    
    // Some fal responses may return image as base64 data url as well
    final String? imageDataUrl = json['image'] as String?;
    if (imageDataUrl != null && imageDataUrl.startsWith('data:')) {
      return _decodeDataUrl(imageDataUrl);
    }

    throw Exception('fal.ai response did not contain an image');
  }

  String _detectMimeType(Uint8List bytes) {
    if (bytes.length >= 4) {
      // JPEG
      if (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
        return 'image/jpeg';
      }
      // PNG
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'image/png';
      }
      // WEBP
      if (bytes.length >= 12 &&
          bytes[0] == 0x52 &&
          bytes[1] == 0x49 &&
          bytes[2] == 0x46 &&
          bytes[3] == 0x46) {
        if (bytes[8] == 0x57 &&
            bytes[9] == 0x45 &&
            bytes[10] == 0x42 &&
            bytes[11] == 0x50) {
          return 'image/webp';
        }
      }
    }
    return 'image/jpeg';
  }

  Uint8List _decodeDataUrl(String dataUrl) {
    final int comma = dataUrl.indexOf(',');
    if (comma == -1) throw Exception('Invalid data URL');
    final String b64 = dataUrl.substring(comma + 1);
    return base64Decode(b64);
  }
}
