class ErrorHandler {
  static const _messages = <String, String>{
    'user already registered': 'An account with this phone number already exists. Try logging in instead.',
    'email already registered': 'An account with this phone number already exists. Try logging in instead.',
    'email not confirmed': 'Please confirm your email address before logging in.',
    'invalid login credentials': 'Wrong password. Try again or reset your password.',
    'password': 'Wrong password. Try again or reset your password.',
  };

  static String friendly(String? error) {
    if (error == null) return '';
    final lower = error.toLowerCase();

    // Check specific messages first
    for (final entry in _messages.entries) {
      if (lower.contains(entry.key)) return entry.value;
    }

    // Then check patterns
    if (lower.contains('42p17') || lower.contains('infinite recursion')) {
      return 'System configuration error. Please contact support.';
    }
    if (lower.contains('42p01') || lower.contains('relation') && lower.contains('does not exist')) {
      return 'System setup incomplete. Please contact support.';
    }
    if (lower.contains('network') || lower.contains('timeout') || lower.contains('socket')) {
      return 'No internet connection. Check your network and try again.';
    }
    if (lower.contains('unique') || lower.contains('duplicate')) {
      return 'This information already exists in our system.';
    }
    if (lower.contains('storage') || lower.contains('upload')) {
      return 'Failed to upload file. Please try again.';
    }
    if (lower.contains('permission') || lower.contains('denied')) {
      return 'Permission denied. Please grant the required permissions in Settings.';
    }
    if (lower.contains('not found') || lower.contains('404')) {
      return 'The requested information was not found.';
    }

    // Generic Supabase auth errors
    if (lower.contains('signup') || lower.contains('sign_up') || lower.contains('provider')) {
      if (lower.contains('disabled') || lower.contains('not enabled') || lower.contains('not allowed')) {
        return 'Account creation is not allowed. Please contact support.';
      }
    }
    if (lower.contains('422') || lower.contains('auth')) {
      return 'Invalid credentials. Please check your information and try again.';
    }

    return 'Something went wrong. Please try again.';
  }

  static String friendlyShort(String? error) {
    if (error == null) return '';
    final lower = error.toLowerCase();

    if (lower.contains('network') || lower.contains('timeout') || lower.contains('socket')) {
      return 'Check your connection';
    }
    if (lower.contains('unique') || lower.contains('duplicate')) {
      return 'Already exists';
    }
    if (lower.contains('auth') || lower.contains('invalid login')) {
      return 'Wrong credentials';
    }
    if (lower.contains('permission')) {
      return 'Permission denied';
    }

    return 'Something went wrong';
  }
}
