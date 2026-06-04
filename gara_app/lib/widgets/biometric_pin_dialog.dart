import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../providers/language_provider.dart';

class BiometricSetupDialog extends StatefulWidget {
  const BiometricSetupDialog({super.key});

  @override
  State<BiometricSetupDialog> createState() => _BiometricSetupDialogState();
}

class _BiometricSetupDialogState extends State<BiometricSetupDialog> {
  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final auth = context.watch<AuthProvider>();

    return AlertDialog(
      title: Text(lang.t('Secure Your Account', 'Teka Umutekano Konti Yawe')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              auth.hasBiometrics ? Icons.fingerprint : Icons.lock_rounded,
              color: AppTheme.primaryGreen,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            auth.hasBiometrics
                ? lang.t('Enable biometric authentication for quick access?',
                    'Emera ikoreshwa ry\'ibimenyetso bya biometric kugirango winjire vuba?')
                : lang.t('Set a 4-digit PIN to secure your account.',
                    'Shyira PIN y\'imibare 4 kugirango uteze umutekano konti yawe.'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lang.t('Skip', 'Reka')),
        ),
        ElevatedButton(
          onPressed: auth.hasBiometrics
              ? () async {
                  await auth.authenticateWithBiometrics();
                  if (context.mounted) Navigator.pop(context);
                }
              : () {
                  Navigator.pop(context);
                  showDialog(context: context, builder: (_) => const PinSetupDialog());
                },
          child: Text(auth.hasBiometrics
              ? lang.t('Enable Biometric', 'Emera Biometric')
              : lang.t('Set PIN', 'Shyira PIN')),
        ),
      ],
    );
  }
}

class PinSetupDialog extends StatefulWidget {
  const PinSetupDialog({super.key});

  @override
  State<PinSetupDialog> createState() => _PinSetupDialogState();
}

class _PinSetupDialogState extends State<PinSetupDialog> {
  final _pinController = TextEditingController();
  final _confirmController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return AlertDialog(
      title: Text(lang.t('Create Security PIN', 'Kora PIN y\'Umutekano')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.lock_rounded, color: AppTheme.primaryGreen, size: 32),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: lang.t('Enter 4-digit PIN', 'Shyiramo PIN y\'imibare 4'),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _confirmController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: lang.t('Confirm PIN', 'Emeza PIN'),
              counterText: '',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(lang.t('Skip', 'Reka')),
        ),
        ElevatedButton(
          onPressed: _savePin,
          child: Text(lang.t('Save PIN', 'Bika PIN')),
        ),
      ],
    );
  }

  Future<void> _savePin() async {
    final pin = _pinController.text.trim();
    final confirm = _confirmController.text.trim();

    if (pin.length != 4) {
      setState(() => _error = 'PIN must be exactly 4 digits');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match');
      return;
    }

    final auth = context.read<AuthProvider>();
    final error = await auth.savePin(pin);
    if (error != null) {
      setState(() => _error = error);
    } else if (context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN saved successfully!'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class PinVerificationDialog extends StatefulWidget {
  const PinVerificationDialog({super.key});

  @override
  State<PinVerificationDialog> createState() => _PinVerificationDialogState();
}

class _PinVerificationDialogState extends State<PinVerificationDialog> {
  final _pinController = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();

    return AlertDialog(
      title: Text(lang.t('Enter PIN', 'Shyiramo PIN')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_rounded, size: 48, color: AppTheme.primaryGreen),
          const SizedBox(height: 16),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.number,
            maxLength: 4,
            obscureText: true,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 24, letterSpacing: 8),
            decoration: InputDecoration(
              hintText: lang.t('Your 4-digit PIN', 'PIN yawe y\'imibare 4'),
              counterText: '',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          if (_error != null) Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(color: AppTheme.errorRed, fontSize: 13)),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _verify,
          child: Text(lang.t('Verify', 'Emeza')),
        ),
      ],
    );
  }

  Future<void> _verify() async {
    final auth = context.read<AuthProvider>();
    final valid = await auth.verifyPin(_pinController.text.trim());
    if (valid) {
      Navigator.pop(context, true);
    } else {
      setState(() => _error = 'Incorrect PIN');
    }
  }
}
