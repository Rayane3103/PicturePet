import 'dart:convert';
import 'package:flutter/foundation.dart';

enum LogLevel { debug, info, warn, error }

class Logger {
  const Logger._();

  static void _log(LogLevel level, String message, {Map<String, Object?> context = const {}}) {
    final now = DateTime.now().toUtc().toIso8601String();
    final payload = <String, Object?>{
      'ts': now,
      'level': describeEnum(level).toUpperCase(),
      'message': message,
      if (context.isNotEmpty) 'context': _sanitize(context),
    };
    // Print a single-line JSON log for easy parsing in tools
    // ignore: avoid_print
    print(jsonEncode(payload));
  }

  static Map<String, Object?> _sanitize(Map<String, Object?> input) {
    final sanitized = <String, Object?>{};
    for (final entry in input.entries) {
      final key = entry.key.toLowerCase();
      if (key.contains('key') || key.contains('secret') || key.contains('token')) {
        sanitized[entry.key] = '***';
      } else {
        sanitized[entry.key] = entry.value;
      }
    }
    return sanitized;
  }

  static void debug(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.debug, message, context: context);
  static void info(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.info, message, context: context);
  static void warn(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.warn, message, context: context);
  static void error(String message, {Map<String, Object?> context = const {}}) =>
      _log(LogLevel.error, message, context: context);
}


