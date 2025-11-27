import 'package:meta/meta.dart';

@immutable
class AiJobException implements Exception {
  final String message;
  const AiJobException(this.message);

  @override
  String toString() => message;
}

class InsufficientCreditsException extends AiJobException {
  final int? requiredCredits;
  final String? toolName;

  const InsufficientCreditsException({
    required String message,
    this.requiredCredits,
    this.toolName,
  }) : super(message);
}

class ToolUnavailableException extends AiJobException {
  const ToolUnavailableException(String message) : super(message);
}

