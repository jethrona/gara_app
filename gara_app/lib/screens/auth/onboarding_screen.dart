import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/password_strength.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/biometric_pin_dialog.dart';
import '../patient/patient_dashboard.dart';
import '../doctor/doctor_dashboard.dart';
import 'doctor_gate_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  final _regNameController = TextEditingController();
  final _regPhoneController = TextEditingController();
  final _regPasswordController = TextEditingController();
  bool _agreedToTerms = false;
  PasswordStrength _passwordStrength = PasswordStrength.veryWeak;

  final _loginPhoneController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  bool _showLoginPassword = false;
  bool _showRegPassword = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<AuthProvider>().clearError();
      }
    });
    _regPasswordController.addListener(_updateStrength);
  }

  void _updateStrength() {
    final s = PasswordStrengthUtil.evaluate(_regPasswordController.text);
    if (s != _passwordStrength) {
      setState(() => _passwordStrength = s);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _regNameController.dispose();
    _regPhoneController.dispose();
    _regPasswordController.dispose();
    _loginPhoneController.dispose();
    _loginPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const DoctorGateScreen()),
                    ),
                    child: Text(
                      lang.t("I'm a Doctor", 'Ndi Muganga'),
                      style: const TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ),
                  const LanguageToggle(),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Icon(Icons.medical_services_rounded, size: 44, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gara',
                      style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lang.t('Your Health, In Your Hands', 'Ubuzima Bwawe mu Biganza Byawe'),
                      style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: TabBar(
                        controller: _tabController,
                        indicatorSize: TabBarIndicatorSize.tab,
                        labelColor: Colors.white,
                        unselectedLabelColor: AppTheme.textSecondary,
                        indicator: BoxDecoration(
                          color: AppTheme.primaryGreen,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tabs: [
                          Tab(text: lang.t('Register', 'Iyandikisha')),
                          Tab(text: lang.t('Login', 'Injira')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      height: 400,
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRegisterForm(lang, auth),
                          _buildLoginForm(lang, auth),
                        ],
                      ),
                    ),
                    if (auth.errorMessage != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: AppTheme.errorRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                auth.errorMessage!,
                                style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterForm(LanguageProvider lang, AuthProvider auth) {
    final strength = _passwordStrength;
    Color barColor;
    switch (strength) {
      case PasswordStrength.veryWeak: barColor = AppTheme.textMuted; break;
      case PasswordStrength.weak: barColor = AppTheme.errorRed; break;
      case PasswordStrength.medium: barColor = AppTheme.accentOrange; break;
      case PasswordStrength.strong: barColor = AppTheme.successGreen; break;
      case PasswordStrength.veryStrong: barColor = AppTheme.primaryGreen; break;
    }
    final barWidth = (strength.index / 4.0).clamp(0.0, 1.0);

    return SingleChildScrollView(
      child: Column(
        children: [
          TextField(
            controller: _regNameController,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(
              labelText: lang.t('Full Name', 'Amazina Yose'),
              hintText: lang.t('e.g. Jean Pierre', 'ex: Jean Pierre'),
              prefixIcon: const Icon(Icons.person_outline),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _regPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: lang.t('Phone Number', 'Nomero ya Telefone'),
              hintText: '078XXXXXXX',
              prefixIcon: const Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _regPasswordController,
            obscureText: !_showRegPassword,
            decoration: InputDecoration(
              labelText: lang.t('Password', 'Ijambo ry\'ibanga'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showRegPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showRegPassword = !_showRegPassword),
              ),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: barWidth, backgroundColor: AppTheme.borderLight, color: barColor, minHeight: 4),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              PasswordStrengthUtil.label(strength),
              style: TextStyle(fontSize: 12, color: barColor, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: _agreedToTerms,
            onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
            title: Text(
              lang.t('I agree to the Terms of Service', 'Nemeye Amategeko'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppTheme.primaryGreen,
          ),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: auth.rememberMe,
            onChanged: (v) => auth.setRememberMe(v ?? false),
            title: Text(
              lang.t('Remember me', 'Mpa kwibuka'),
              style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
            ),
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: AppTheme.primaryGreen,
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_agreedToTerms && !auth.isLoading) ? () => _register(lang) : null,
              child: auth.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(lang.t('Create Account', 'Fungura Konti')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(LanguageProvider lang, AuthProvider auth) {
    return SingleChildScrollView(
      child: Column(
        children: [
          const SizedBox(height: 20),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.login_rounded, size: 36, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _loginPhoneController,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: lang.t('Phone Number', 'Nomero ya Telefone'),
              prefixIcon: const Icon(Icons.phone_android),
            ),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _loginPasswordController,
            obscureText: !_showLoginPassword,
            decoration: InputDecoration(
              labelText: lang.t('Password', 'Ijambo ry\'ibanga'),
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_showLoginPassword ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showLoginPassword = !_showLoginPassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Checkbox(
                value: auth.rememberMe,
                onChanged: (v) => auth.setRememberMe(v ?? false),
                activeColor: AppTheme.primaryGreen,
              ),
              Text(lang.t('Remember me', 'Mpa kwibuka'), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              const Spacer(),
              TextButton(
                onPressed: () => _showForgotPassword(lang),
                child: Text(
                  lang.t('Forgot password?', 'Wibagiwe ijambo ry\'ibanga?'),
                  style: const TextStyle(fontSize: 13, color: AppTheme.primaryGreen),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: !auth.isLoading ? () => _login(lang) : null,
              child: auth.isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(lang.t('Sign In', 'Injira')),
            ),
          ),
        ],
      ),
    );
  }

  void _showForgotPassword(LanguageProvider lang) {
    final phoneController = TextEditingController();
    final otpController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool showNewPassword = false;
    bool processing = false;
    bool codeSent = false;
    String? statusMsg;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(lang.t('Reset Password', 'Guhindura ijambo ry\'ibanga')),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!codeSent) ...[
                  Text(lang.t('Enter your phone number to receive a reset code.', 'Shyiramo numero yawe kugirango wakire kode yo guhindura.')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: lang.t('Phone Number', 'Nomero ya Telefone'),
                      prefixIcon: const Icon(Icons.phone_android),
                    ),
                  ),
                ] else ...[
                  Text(lang.t('Enter the reset code and your new password.', 'Shyiramo kode n\'ijambo ry\'ibanga rishya.')),
                  const SizedBox(height: 16),
                  TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    decoration: InputDecoration(
                      labelText: lang.t('Reset Code', 'Kode yo Guhindura'),
                      prefixIcon: const Icon(Icons.pin),
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: newPasswordController,
                    obscureText: !showNewPassword,
                    decoration: InputDecoration(
                      labelText: lang.t('New Password', 'Ijambo ry\'ibanga rishya'),
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(showNewPassword ? Icons.visibility_off : Icons.visibility),
                        onPressed: () => setDialogState(() => showNewPassword = !showNewPassword),
                      ),
                    ),
                  ),
                ],
                if (statusMsg != null) ...[
                  const SizedBox(height: 12),
                  Text(statusMsg!, style: TextStyle(color: statusMsg!.contains('✅') ? AppTheme.successGreen : AppTheme.errorRed, fontSize: 13)),
                ],
                if (processing) const Padding(padding: EdgeInsets.only(top: 12), child: Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: processing ? null : () => Navigator.pop(ctx),
              child: Text(lang.t('Cancel', 'Guhagarika')),
            ),
            TextButton(
              onPressed: processing ? null : () async {
                final auth = context.read<AuthProvider>();

                if (!codeSent) {
                  final phone = phoneController.text.trim();
                  if (phone.isEmpty) return;
                  setDialogState(() { processing = true; statusMsg = null; });
                  final error = await auth.sendPasswordResetOtp(phone);
                  setDialogState(() {
                    processing = false;
                    if (error == null) {
                      statusMsg = '✅ Reset code sent to your phone. Check the debug console or SMS.';
                      codeSent = true;
                    } else {
                      statusMsg = error;
                    }
                  });
                } else {
                  final otp = otpController.text.trim();
                  final newPassword = newPasswordController.text.trim();
                  if (otp.length < 4) return;
                  if (newPassword.length < 6) {
                    setDialogState(() => statusMsg = 'Password must be at least 6 characters');
                    return;
                  }
                  setDialogState(() { processing = true; statusMsg = null; });
                  final error = await auth.verifyResetOtpAndUpdatePassword(
                    phone: phoneController.text.trim(),
                    otp: otp,
                    newPassword: newPassword,
                  );
                  setDialogState(() {
                    processing = false;
                    if (error == null) {
                      statusMsg = '✅ Password reset successfully';
                      Future.delayed(const Duration(seconds: 1), () {
                        if (ctx.mounted) Navigator.pop(ctx);
                      });
                    } else {
                      statusMsg = error;
                    }
                  });
                }
              },
              child: Text(codeSent ? lang.t('Reset', 'Hindura') : lang.t('Send Code', 'Ohereza Kode')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _register(LanguageProvider lang) async {
    final name = _regNameController.text.trim();
    final rawPhone = _regPhoneController.text.trim();
    final phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    final password = _regPasswordController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('Please enter your full name', 'Uzuza amazina yawe')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('Enter a valid phone number (10+ digits)', 'Shyiramo nomero ikwiye (10+ imibare)')), behavior: SnackBarBehavior.floating),
      );
      return;
    }
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('Password must be at least 6 characters', 'Ijambo ry\'ibanga rigomba kuba byibura 6')), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.registerPatient(
      phoneNumber: phone,
      fullName: name,
      password: password,
    );

    if (error == null && mounted) {
      auth.clearError();
      await _checkBiometricSetup();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PatientDashboard()),
        );
      }
    }
  }

  Future<void> _login(LanguageProvider lang) async {
    final rawPhone = _loginPhoneController.text.trim();
    final phone = rawPhone.replaceAll(RegExp(r'\D'), '');
    final password = _loginPasswordController.text.trim();

    if (phone.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(lang.t('Please fill all fields', 'Uzuza ibisabwa byose')), behavior: SnackBarBehavior.floating),
      );
      return;
    }

    final auth = context.read<AuthProvider>();
    auth.clearError();
    final error = await auth.loginPatient(
      phoneNumber: phone,
      password: password,
    );

    if (error == null && mounted) {
      final dest = auth.isDoctor
          ? const DoctorDashboard()
          : const PatientDashboard();
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => dest),
      );
    }
  }

  Future<void> _checkBiometricSetup() async {
    final auth = context.read<AuthProvider>();
    if (auth.hasBiometrics) {
      await auth.authenticateWithBiometrics();
    } else if (!auth.hasPin) {
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => const PinSetupDialog(),
      );
    }
  }
}
