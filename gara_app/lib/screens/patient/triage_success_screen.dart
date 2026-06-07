import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/language_provider.dart';
import '../../services/supabase_service.dart';
import 'patient_dashboard.dart';

class TriageSuccessScreen extends StatefulWidget {
  final ConsultationModel consultation;

  const TriageSuccessScreen({super.key, required this.consultation});

  @override
  State<TriageSuccessScreen> createState() => _TriageSuccessScreenState();
}

class _TriageSuccessScreenState extends State<TriageSuccessScreen>
    with SingleTickerProviderStateMixin {
  String _doctorName = '';
  String _doctorClinic = '';
  String _doctorPhone = '';
  int _doctorFee = 2000;
  bool _loadingDoctor = true;
  String? _fetchError;

  late AnimationController _animController;
  late Animation<double> _scaleAnim;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 600),
    );
    _scaleAnim = CurvedAnimation(parent: _animController, curve: Curves.elasticOut);
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();
    _fetchDoctorInfo();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _fetchDoctorInfo() async {
    try {
      final res = await SupabaseService().client
          .from('profiles')
          .select('full_name, clinic_name, phone_number, consultation_fee')
          .eq('is_doctor', true)
          .limit(1)
          .maybeSingle();
      if (!mounted) return;
      if (res == null) {
        setState(() {
          _fetchError = 'Doctor profile not found. Ask your doctor to complete their profile setup.';
          _loadingDoctor = false;
        });
        return;
      }
      setState(() {
        _doctorName = (res['full_name'] as String?)?.trim() ?? '';
        _doctorClinic = (res['clinic_name'] as String?)?.trim() ?? '';
        _doctorPhone = (res['phone_number'] as String?)?.trim() ?? '';
        _doctorFee = (res['consultation_fee'] as int?) ?? 2000;
        _loadingDoctor = false;
        if (_doctorName.isEmpty && _doctorPhone.isEmpty) {
          _fetchError = 'Doctor has not set up their payment info yet.\nContact your doctor to complete their Settings.';
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fetchError = 'Could not load doctor info: $e';
        _loadingDoctor = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final hasBrief = widget.consultation.aiBriefSummary != null &&
        widget.consultation.aiBriefSummary!.isNotEmpty &&
        !widget.consultation.aiBriefSummary!.startsWith('AI synthesis unavailable') &&
        !widget.consultation.aiBriefSummary!.startsWith('Unable to');

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Column(
                  children: [
                    ScaleTransition(
                      scale: _scaleAnim,
                      child: Container(
                        width: 88, height: 88,
                        decoration: BoxDecoration(
                          color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.check_circle_rounded, size: 52, color: AppTheme.primaryGreen),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FadeTransition(
                      opacity: _fadeAnim,
                      child: Column(
                        children: [
                          Text(lang.t('Triage Submitted!', 'Uburwayi Bwoherejwe!'),
                              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.textPrimary)),
                          const SizedBox(height: 8),
                          Text(lang.t('Consultation #${widget.consultation.id}', 'Ubuvuzi #${widget.consultation.id}'),
                              style: const TextStyle(fontSize: 14, color: AppTheme.textMuted)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              _buildSectionHeader(lang.t('Step 1 — Pay to Activate', 'Intambwe 1 — Tanga Amafaranga'), Icons.payment_rounded, AppTheme.warningYellow),
              const SizedBox(height: 12),
              _loadingDoctor
                  ? _buildLoadingCard()
                  : _fetchError != null
                      ? _buildErrorCard(_fetchError!)
                      : _buildPaymentCard(lang),
              const SizedBox(height: 24),
              _buildSectionHeader(lang.t('Step 2 — Wait for Confirmation', 'Intambwe 2 — Tegereza Kwemezwa'), Icons.hourglass_top_rounded, AppTheme.accentBlue),
              const SizedBox(height: 12),
              _buildInfoCard(
                lang.t(
                  'After you send payment, the doctor will verify it and move you to Active status. You will receive a notification and be taken directly to the chat.',
                  'Nyuma yo kohereza amafaranga, umuganga azayemeza akakwimura ku ntera ya Mukora. Uzabona imenyesha kandi uzajyana mu kiganiro.',
                ),
                Icons.notifications_active_rounded, AppTheme.accentBlue,
              ),
              const SizedBox(height: 24),
              if (hasBrief) ...[
                _buildSectionHeader(lang.t('AI Clinical Brief', 'Incamake y\'Ubuzima by\'AI'), Icons.psychology_rounded, AppTheme.primaryGreen),
                const SizedBox(height: 12),
                _buildAiBriefCard(widget.consultation.aiBriefSummary!, lang),
              ] else ...[
                _buildInfoCard(
                  lang.t('AI clinical brief could not be generated. The doctor will review your symptoms directly.', 'Incamake y\'AI ntiyakozwe. Umuganga azasuzuma indwara zawe bwite.'),
                  Icons.info_outline_rounded, AppTheme.textMuted,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const PatientDashboard()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.dashboard_rounded),
                  label: Text(lang.t('Go to Dashboard', 'Jya ku Kibaho')),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
          child: Icon(icon, size: 20, color: color),
        ),
        const SizedBox(width: 10),
        Expanded(child: Text(title, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color == AppTheme.textMuted ? AppTheme.textSecondary : color))),
      ],
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.borderLight)),
      child: const Row(
        children: [
          SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          SizedBox(width: 12),
          Text('Loading doctor payment info...'),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.errorRed.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.errorRed.withValues(alpha: 0.3))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_rounded, color: AppTheme.errorRed, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(fontSize: 13, color: AppTheme.errorRed))),
        ],
      ),
    );
  }

  Widget _buildPaymentCard(LanguageProvider lang) {
    final displayName = _doctorName.isNotEmpty ? _doctorName : 'Doctor';
    final displayPhone = _doctorPhone.isNotEmpty ? _doctorPhone : '\u2014';
    final displayClinic = _doctorClinic.isNotEmpty ? _doctorClinic : '';

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.4)),
        boxShadow: [BoxShadow(color: AppTheme.warningYellow.withValues(alpha: 0.08), blurRadius: 12, offset: const Offset(0, 4))],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AppTheme.warningYellow.withValues(alpha: 0.1), borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
            child: Column(
              children: [
                Text(lang.t('Amount to Pay', 'Amafaranga Atangwa'), style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('$_doctorFee RWF', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppTheme.warningYellow)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _paymentRow(lang.t('Send To', 'Ohereza Kuri'), displayPhone, Icons.phone_rounded, copyable: true),
                const Divider(height: 20),
                _paymentRow(lang.t('Doctor', 'Umuganga'), displayName, Icons.medical_services_rounded),
                if (displayClinic.isNotEmpty) ...[
                  const Divider(height: 20),
                  _paymentRow(lang.t('Clinic', 'Ivuriro'), displayClinic, Icons.local_hospital_rounded),
                ],
                const Divider(height: 20),
                _paymentRow(lang.t('Method', 'Uburyo'), 'MoMo (*182#)', Icons.smartphone_rounded),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.07), borderRadius: const BorderRadius.vertical(bottom: Radius.circular(16))),
            child: Text(
              lang.t(
                'Dial *182# \u2192 Send Money \u2192 Enter $_doctorPhone \u2192 Amount: $_doctorFee RWF \u2192 Confirm',
                'Dial *182# \u2192 Ohereza Amafaranga \u2192 Injiza $_doctorPhone \u2192 Amafaranga: $_doctorFee RWF \u2192 Emeza',
              ),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentRow(String label, String value, IconData icon, {bool copyable = false}) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppTheme.textMuted),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
            ],
          ),
        ),
        if (copyable)
          GestureDetector(
            onTap: () {
              Clipboard.setData(ClipboardData(text: value));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Phone number copied!'), duration: Duration(seconds: 2)),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: AppTheme.primaryGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Text('Copy', style: TextStyle(fontSize: 12, color: AppTheme.primaryGreen, fontWeight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }

  Widget _buildInfoCard(String message, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(14), border: Border.all(color: color.withValues(alpha: 0.2))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: TextStyle(fontSize: 13, color: color == AppTheme.textMuted ? AppTheme.textSecondary : AppTheme.textPrimary))),
        ],
      ),
    );
  }

  Widget _buildAiBriefCard(String brief, LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.2))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome_rounded, size: 16, color: AppTheme.primaryGreen),
              const SizedBox(width: 6),
              Text(lang.t('Generated by AI \u2022 For doctor review only', 'Yakozwe na AI \u2022 Kuri umuganga gusa'), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(),
          const SizedBox(height: 10),
          Text(brief, style: const TextStyle(fontSize: 13, color: AppTheme.textPrimary, height: 1.5)),
        ],
      ),
    );
  }
}
