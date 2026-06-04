enum PasswordStrength { veryWeak, weak, medium, strong, veryStrong }

class PasswordStrengthUtil {
  static const _minLength = 8;

  static PasswordStrength evaluate(String password) {
    if (password.isEmpty) return PasswordStrength.veryWeak;
    if (password.length < _minLength) return PasswordStrength.veryWeak;

    int score = 0;

    if (password.length >= 12) score++;
    if (password.contains(RegExp(r'[A-Z]'))) score++;
    if (password.contains(RegExp(r'[a-z]'))) score++;
    if (password.contains(RegExp(r'[0-9]'))) score++;
    if (password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'))) score++;

    if (score <= 1) return PasswordStrength.weak;
    if (score == 2) return PasswordStrength.medium;
    if (score <= 4) return PasswordStrength.strong;
    return PasswordStrength.veryStrong;
  }

  static String label(PasswordStrength s) {
    switch (s) {
      case PasswordStrength.veryWeak: return 'Too short (min 8)';
      case PasswordStrength.weak: return 'Weak';
      case PasswordStrength.medium: return 'Medium';
      case PasswordStrength.strong: return 'Strong';
      case PasswordStrength.veryStrong: return 'Very strong';
    }
  }
}
