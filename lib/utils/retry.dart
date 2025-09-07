import 'dart:async';

typedef Retryable<T> = Future<T> Function();

class RetryPolicy {
  final int maxAttempts;
  final Duration initialBackoff;
  final double backoffFactor;
  final Duration? maxBackoff;

  const RetryPolicy({
    this.maxAttempts = 3,
    this.initialBackoff = const Duration(milliseconds: 300),
    this.backoffFactor = 2.0,
    this.maxBackoff,
  }) : assert(maxAttempts > 0);

  Duration backoffForAttempt(int attempt) {
    final raw = initialBackoff * (backoffFactor.pow(attempt - 1));
    if (maxBackoff == null) return raw;
    return raw > maxBackoff! ? maxBackoff! : raw;
  }
}

extension on Duration {
  Duration operator *(double factor) {
    return Duration(microseconds: (inMicroseconds * factor).round());
  }
}

extension on double {
  double pow(int exponent) {
    double result = 1.0;
    for (int i = 0; i < exponent; i++) {
      result *= this;
    }
    return result;
  }
}

Future<T> retry<T>(Retryable<T> task, {RetryPolicy policy = const RetryPolicy()}) async {
  int attempt = 0;
  while (true) {
    attempt += 1;
    try {
      return await task();
    } catch (e) {
      if (attempt >= policy.maxAttempts) rethrow;
      final delay = policy.backoffForAttempt(attempt);
      await Future.delayed(delay);
    }
  }
}


