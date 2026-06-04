import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import 'auth/onboarding_screen.dart';
import 'patient/patient_dashboard.dart';
import 'doctor/doctor_dashboard.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _scaleAnim = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.elasticOut),
    );
    _animController.forward();
    _initAndNavigate();
  }

  Future<void> _initAndNavigate() async {
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    await authProvider.init();

    if (!mounted) return;

    if (authProvider.isLoggedIn) {
      _navigateToDashboard(authProvider.isDoctor);
      return;
    }

    final autoLoggedIn = await authProvider.tryAutoLogin();
    if (!mounted) return;

    if (autoLoggedIn) {
      _navigateToDashboard(authProvider.isDoctor);
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const OnboardingScreen()),
      );
    }
  }

  void _navigateToDashboard(bool isDoctor) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => isDoctor ? const DoctorDashboard() : const PatientDashboard(),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppTheme.primaryGreen, AppTheme.primaryGreenDark],
          ),
        ),
        child: AnimatedBuilder(
          animation: _animController,
          builder: (context, child) => Opacity(
            opacity: _fadeAnim.value,
            child: Transform.scale(
              scale: _scaleAnim.value,
              child: child,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.medical_services_rounded,
                    size: 56,
                    color: AppTheme.primaryGreen,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Gara',
                style: TextStyle(
                  fontSize: 42,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your Health, In Your Hands',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withValues(alpha: 0.85),
                  fontWeight: FontWeight.w400,
                ),
              ),
              const SizedBox(height: 48),
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
