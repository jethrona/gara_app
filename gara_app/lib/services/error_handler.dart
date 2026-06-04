class ErrorHandler {
  static String friendly(String? error) {
    if (error == null) return '';
    final lower = error.toLowerCase();

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
    if (lower.contains('422') || lower.contains('anonymous') && lower.contains('disabled')) {
      return 'Sign-up is not allowed. Make sure the Email provider is enabled in Supabase Auth settings.';
    }
    if (lower.contains('auth') || lower.contains('invalid login') || lower.contains('wrong')) {
      return 'Invalid credentials. Please check your information and try again.';
    }
    if (lower.contains('user already registered') || lower.contains('email already registered')) {
      return 'An account with this phone number already exists. Try logging in instead.';
    }
    if (lower.contains('email not confirmed') || lower.contains('email_confirmed')) {
      return 'Please confirm your email address before logging in.';
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
