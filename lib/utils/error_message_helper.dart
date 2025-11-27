import 'dart:io';

/// Converts technical exceptions to user-friendly error messages
class ErrorMessageHelper {
  /// Returns a user-friendly error message for network/connection errors
  static String getUserFriendlyMessage(Object error) {
    final errorString = error.toString().toLowerCase();
    
    // Check for network/connection errors
    if (_isNetworkError(error, errorString)) {
      return 'No internet connection. Please check your network and try again.';
    }
    
    // Check for timeout errors
    if (errorString.contains('timeout') || 
        errorString.contains('timed out') ||
        errorString.contains('deadline exceeded')) {
      return 'Request timed out. Please check your connection and try again.';
    }
    
    // Check for server errors
    if (errorString.contains('500') || 
        errorString.contains('502') || 
        errorString.contains('503') ||
        errorString.contains('504')) {
      return 'Server error. Please try again later.';
    }
    
    // Check for authentication errors
    if (errorString.contains('401') || 
        errorString.contains('unauthorized') ||
        errorString.contains('authentication')) {
      return 'Authentication failed. Please log in again.';
    }
    
    // Check for not found errors
    if (errorString.contains('404') || 
        errorString.contains('not found')) {
      return 'The requested resource was not found.';
    }
    
    // Generic error message for unknown errors
    return 'Something went wrong. Please try again.';
  }
  
  /// Checks if the error is a network/connection error
  static bool _isNetworkError(Object error, String errorString) {
    // Check for SocketException
    if (error is SocketException) {
      return true;
    }
    
    // Check for common network error patterns
    if (errorString.contains('failed host lookup') ||
        errorString.contains('no address associated with hostname') ||
        errorString.contains('network is unreachable') ||
        errorString.contains('no internet') ||
        errorString.contains('connection refused') ||
        errorString.contains('connection reset') ||
        errorString.contains('connection closed') ||
        errorString.contains('connection timed out') ||
        errorString.contains('socketexception') ||
        errorString.contains('clientexception') ||
        errorString.contains('networkerror') ||
        errorString.contains('network error') ||
        errorString.contains('unable to resolve host') ||
        errorString.contains('errno = 7') ||
        errorString.contains('errno = 8') ||
        errorString.contains('errno = 101') ||
        errorString.contains('errno = 110') ||
        errorString.contains('errno = 111') ||
        errorString.contains('errno = 113')) {
      return true;
    }
    
    return false;
  }
  
  /// Checks if the error is a network error (public method)
  static bool isNetworkError(Object error) {
    return _isNetworkError(error, error.toString().toLowerCase());
  }
}

