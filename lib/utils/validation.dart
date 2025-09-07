class Validation {
  const Validation._();

  static String? nonEmpty(String? value, {String fieldName = 'Field'}) {
    if (value == null || value.trim().isEmpty) return '$fieldName is required';
    return null;
  }

  static String? url(String? value, {String fieldName = 'URL'}) {
    if (value == null || value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null || (!uri.hasScheme || !uri.hasAuthority)) {
      return 'Invalid $fieldName';
    }
    return null;
  }
}


