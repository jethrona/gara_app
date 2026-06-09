import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/language_toggle.dart';
import '../doctor/doctor_dashboard.dart';

class DoctorGateScreen extends StatefulWidget {
  const DoctorGateScreen({super.key});

  @override
  State<DoctorGateScreen> createState() => _DoctorGateScreenState();
}

class _DoctorGateScreenState extends State<DoctorGateScreen> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _tokenController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _showToken = false;
  bool _showPassword = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _tokenController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(lang.t('Doctor Registration', 'Iyandikisha ry\'Umuganga')),
        actions: const [Padding(padding: EdgeInsets.only(right: 8), child: LanguageToggle())],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.medical_information_rounded, size: 40, color: AppTheme.primaryGreen),
                ),
                const SizedBox(height: 20),
                Text(
                  lang.t('Doctor Registration', 'Iyandikisha ry\'Umuganga'),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                ),
                const SizedBox(height: 8),
                Text(
                  lang.t(
                    'This registration is locked. You need a special token to register as a doctor.',
                    'Iyi ndangantego irakenewe. Ukeneye token yihariye kugirango wiyandikishe nk\'umuganga.',
                  ),
                  style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: InputDecoration(
                    labelText: lang.t('Full Name', 'Amazina Yose'),
                    prefixIcon: const Icon(Icons.person_outline),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: lang.t('Phone Number', 'Nomero ya Telefone'),
                    prefixIcon: const Icon(Icons.phone_android),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: lang.t('Email (for password reset)', 'Imeri (yo guhindura ijambo ry\'ibanga)'),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: lang.t('Password', 'Ijambo ry\'ibanga'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().length < 6 ? 'Min 6 characters' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _tokenController,
                  obscureText: !_showToken,
                  decoration: InputDecoration(
                    labelText: lang.t('Registration Token', 'Token y\'Iyandikisha'),
                    prefixIcon: const Icon(Icons.vpn_key_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(_showToken ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _showToken = !_showToken),
                    ),
                  ),
                  validator: (v) => v == null || v.trim().isEmpty ? 'Token required' : null,
                ),
                const SizedBox(height: 24),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    return SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: auth.isLoading ? null : _register,
                        icon: auth.isLoading
                            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.shield_rounded),
                        label: Text(auth.isLoading ? '' : lang.t('Register as Doctor', 'Iyandikishe nk\'Umuganga')),
                      ),
                    );
                  },
                ),
                if (context.watch<AuthProvider>().errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.errorRed.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppTheme.errorRed, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              context.watch<AuthProvider>().errorMessage!,
                              style: const TextStyle(color: AppTheme.errorRed, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _register() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthProvider>();
    final phone = _phoneController.text.trim().replaceAll(RegExp(r'\D'), '');
    final error = await auth.registerDoctor(
      phoneNumber: phone,
      fullName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      registrationToken: _tokenController.text.trim(),
      password: _passwordController.text.trim(),
    );

    if (error == null && mounted) {
      auth.clearError();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DoctorDashboard()),
        (route) => false,
      );
    }
  }
}
