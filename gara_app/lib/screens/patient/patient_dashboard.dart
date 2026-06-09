import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/follow_up_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/notification_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/status_tracker_card.dart';
import '../../models/notification_model.dart';
import '../../models/follow_up_model.dart';
import 'triage_form.dart';
import 'triage_success_screen.dart';
import 'patient_chat_screen.dart';
import 'documents_screen.dart';
import '../auth/onboarding_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> with WidgetsBindingObserver {
  int _currentTab = 0;
  String _doctorName = 'Doctor';
  String _doctorClinic = '';
  String _doctorPhone = '';
  int _doctorFee = 2000;
  bool _hasAutoNavigated = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _initAfterBuild());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fetchDoctorProfile();
    }
  }

  Future<void> _fetchDoctorProfile() async {
    try {
      final res = await SupabaseService().client
          .from('profiles')
          .select('full_name, clinic_name, phone_number, consultation_fee')
          .eq('is_doctor', true)
          .limit(1)
          .maybeSingle();
      if (res != null) {
        if (mounted) setState(() {
          _doctorName = res['full_name'] as String? ?? 'Doctor';
          _doctorClinic = res['clinic_name'] as String? ?? '';
          _doctorPhone = res['phone_number'] as String? ?? '';
          _doctorFee = res['consultation_fee'] as int? ?? 2000;
        });
      }
    } catch (e) {
      debugPrint('_fetchDoctorProfile error: $e');
    }
  }

  void _initAfterBuild() {
    final auth = context.read<AuthProvider>();
    final consultationProvider = context.read<ConsultationProvider>();
    final notifProvider = context.read<NotificationProvider>();
    final followUpProvider = context.read<FollowUpProvider>();
    if (auth.userId.isNotEmpty) {
      _fetchDoctorProfile();
      consultationProvider.loadPatientConsultations(auth.userId);
      consultationProvider.startPatientRealtimeListener(auth.userId);
      notifProvider.init(auth.userId);
      followUpProvider.initAsPatient(auth.userId);
      notifProvider.setOnPaymentReceived(() async {
        await consultationProvider.loadPatientConsultations(auth.userId);
        _autoNavigateToChat(auth.userId);
      });
    }
  }

  Future<void> _loadData() async {
    _hasAutoNavigated = false;
    final auth = context.read<AuthProvider>();
    final consultationProvider = context.read<ConsultationProvider>();
    final notifProvider = context.read<NotificationProvider>();
    if (auth.userId.isNotEmpty) {
      await Future.wait([
        _fetchDoctorProfile(),
        consultationProvider.loadPatientConsultations(auth.userId),
      ]);
      consultationProvider.startPatientRealtimeListener(auth.userId);
      notifProvider.init(auth.userId);
      notifProvider.setOnPaymentReceived(() async {
        await consultationProvider.loadPatientConsultations(auth.userId);
        _autoNavigateToChat(auth.userId);
      });
    }
  }

  void _autoNavigateToChat(String userId) {
    if (!mounted || _hasAutoNavigated) return;
    final consultations = context.read<ConsultationProvider>().patientConsultations;
    final active = consultations.where((c) => c.status == CareStatus.inProcess).firstOrNull;
    if (active != null) {
      _hasAutoNavigated = true;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PatientChatScreen(consultation: active)),
      ).then((_) => _hasAutoNavigated = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final consultationProvider = context.watch<ConsultationProvider>();
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();

    final activeConsultation = consultationProvider.patientConsultations.isNotEmpty
        ? consultationProvider.patientConsultations.first
        : null;

    final pendingCount = consultationProvider.patientConsultations
        .where((c) => c.status == CareStatus.pendingPayment)
        .length;
    final inProcessCount = consultationProvider.patientConsultations
        .where((c) => c.status == CareStatus.inProcess)
        .length;
    final completedCount = consultationProvider.patientConsultations
        .where((c) => c.status == CareStatus.complete)
        .length;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Text(lang.t('My Health', 'Ubuzima Bwanjye')),
        actions: [
          Stack(
            children: [
              IconButton(
                icon: const Icon(Icons.notifications_outlined),
                onPressed: () => _showNotifications(lang),
              ),
              if (notifProvider.unreadCount > 0)
                Positioned(
                  right: 6,
                  top: 6,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.errorRed,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${notifProvider.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
          const Padding(padding: EdgeInsets.only(right: 4), child: LanguageToggle()),
        ],
      ),
      body: IndexedStack(
        index: _currentTab,
        children: [
          _buildDashboard(lang, activeConsultation, pendingCount, inProcessCount, completedCount),
          const DocumentsScreen(),
          _buildProfileTab(lang, auth),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTab,
        onTap: (i) => setState(() => _currentTab = i),
        items: [
          BottomNavigationBarItem(icon: const Icon(Icons.dashboard_rounded), label: lang.t('Dashboard', 'Ikibaho')),
          BottomNavigationBarItem(icon: const Icon(Icons.folder_rounded), label: lang.t('Documents', 'Inyandiko')),
          BottomNavigationBarItem(icon: const Icon(Icons.person_rounded), label: lang.t('Profile', 'Profili')),
        ],
      ),
    );
  }

  void _showNotifications(LanguageProvider lang) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        expand: false,
        builder: (_, scrollController) => StatefulBuilder(
          builder: (ctx, setSheetState) {
            final notifProvider = context.watch<NotificationProvider>();
            return Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(lang.t('Notifications', 'Imenyesha'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                      if (notifProvider.unreadCount > 0)
                        TextButton(
                          onPressed: () => notifProvider.markAllAsRead(),
                          child: Text(lang.t('Mark all read', 'Soma zose')),
                        ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: notifProvider.notifications.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.notifications_none, size: 48, color: AppTheme.textMuted),
                                const SizedBox(height: 12),
                                Text(lang.t('No notifications', 'Nta menyesha'), style: const TextStyle(color: AppTheme.textMuted)),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: notifProvider.notifications.length,
                            itemBuilder: (_, i) {
                              final n = notifProvider.notifications[i];
                              return ListTile(
                                leading: Icon(
                                  n.type == 'payment' ? Icons.payments_rounded :
                                  n.type == 'consultation' ? Icons.medical_services_rounded :
                                  n.type == 'follow_up' ? Icons.follow_the_signs_rounded :
                                  Icons.info_rounded,
                                  color: n.isRead ? AppTheme.textMuted : AppTheme.primaryGreen,
                                ),
                                title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600)),
                                subtitle: Text(n.body, style: const TextStyle(fontSize: 12)),
                                trailing: n.isRead ? null : Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGreen)),
                                onTap: () async {
                                  if (n.id != null) {
                                    await notifProvider.markAsRead(n.id!);
                                  }
                                  if (ctx.mounted) Navigator.pop(ctx);
                                  _handleNotificationTap(n);
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  void _handleNotificationTap(NotificationModel n) {
    if (n.type == 'follow_up') {
      _showFollowUpReplyDialog(n);
      return;
    }
    if (n.type == 'payment' || n.type == 'consultation') {
      if (n.consultationId != null) {
        final consultation = context.read<ConsultationProvider>().patientConsultations
            .where((c) => c.id == n.consultationId)
            .firstOrNull;
        if (consultation != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => PatientChatScreen(consultation: consultation),
            ),
          );
          return;
        }
      }
      final active = context.read<ConsultationProvider>().patientConsultations
          .where((c) => c.status == CareStatus.inProcess || c.status == CareStatus.pendingPayment)
          .firstOrNull;
      if (active != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientChatScreen(consultation: active),
          ),
        );
      }
    }
  }

  void _showFollowUpReplyDialog(NotificationModel n) {
    final lang2 = context.read<LanguageProvider>();
    final followUpProvider = context.read<FollowUpProvider>();
    final followUp = followUpProvider.followUps.isNotEmpty
        ? followUpProvider.followUps.first
        : null;

    if (followUp == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang2.t('No follow-up found.', 'Nta gukurikirana bibonetse.')),
      ));
      return;
    }

    if (followUp.hasReply) {
      _showFollowUpDetails(followUp, lang2);
      return;
    }

    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang2.t('Follow-up Reply', 'Igisubizo cyo gukurikirana')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lang2.t('Doctor:', 'Muganga:')} ${followUp.doctorName ?? lang2.t('Doctor', 'Muganga')}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(followUp.doctorMessage),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: lang2.t('Type your reply...', 'Andika igisubizo cyawe...'),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang2.t('Cancel', 'Reka'))),
          FilledButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              final auth = context.read<AuthProvider>();
              await followUpProvider.submitReply(
                followUpId: followUp.id!,
                patientReply: controller.text.trim(),
                doctorId: followUp.doctorId,
                onReplied: () {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(lang2.t('Reply sent!', 'Igisubizo cyoherejwe!')),
                      backgroundColor: AppTheme.primaryGreen,
                    ));
                  }
                },
              );
            },
            child: Text(lang2.t('Send Reply', 'Ohereza Igisubizo')),
          ),
        ],
      ),
    );
  }

  void _showFollowUpDetails(FollowUpModel followUp, LanguageProvider lang2) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang2.t('Follow-up', 'Gukurikirana')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lang2.t('Doctor:', 'Muganga:')} ${followUp.doctorName ?? lang2.t('Doctor', 'Muganga')}'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.surfaceBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(followUp.doctorMessage),
            ),
            if (followUp.hasReply) ...[
              const Divider(height: 20),
              Text(lang2.t('Your Reply:', 'Igisubizo cyawe:'), style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(followUp.patientReply!),
              const SizedBox(height: 4),
              Text(
                followUp.repliedAt?.toLocal().toString().substring(0, 16) ?? '',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang2.t('Close', 'Funga'))),
        ],
      ),
    );
  }

  Widget _buildDashboard(LanguageProvider lang, ConsultationModel? active,
      int pendingCount, int inProcessCount, int completedCount) {
    final consultationProvider = context.read<ConsultationProvider>();
    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active != null) StatusTrackerCard(
              consultation: active,
              doctorName: _doctorName,
              doctorClinic: _doctorClinic.isNotEmpty ? _doctorClinic : null,
              doctorPhone: _doctorPhone,
              doctorFee: _doctorFee,
            ),
            const SizedBox(height: 20),
            _buildQuickStats(lang, pendingCount, inProcessCount, completedCount),
            const SizedBox(height: 20),
            _buildStartConsultation(lang),
            const SizedBox(height: 20),
            if (active != null) _buildActiveConsultationCard(lang, active),
            if (consultationProvider.patientConsultations.length > 1) ...[
              const SizedBox(height: 20),
              _buildHistorySection(lang, consultationProvider.patientConsultations),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickStats(LanguageProvider lang, int pending, int inProcess, int completed) {
    return Row(
      children: [
        _statCard(lang.t('Pending', 'Itegereje'), pending, AppTheme.statusPending, Icons.hourglass_empty_rounded),
        const SizedBox(width: 8),
        _statCard(lang.t('Active', 'Igikora'), inProcess, AppTheme.statusInProcess, Icons.chat_rounded),
        const SizedBox(width: 8),
        _statCard(lang.t('Done', 'Byarangiye'), completed, AppTheme.statusComplete, Icons.check_circle_rounded),
      ],
    );
  }

  Widget _statCard(String label, int count, Color color, IconData icon) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text('$count', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildStartConsultation(LanguageProvider lang) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [AppTheme.primaryGreen, AppTheme.primaryGreenDark]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: AppTheme.primaryGreen.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.add_circle_rounded, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(lang.t('New Consultation', 'Gushaka Ubuvuzi'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text(lang.t('Start a new medical consultation', 'Tangira ubuvuzi bushya'), style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () async {
                final result = await Navigator.push<ConsultationModel>(
                  context,
                  MaterialPageRoute(builder: (_) => const TriageForm()),
                );
                if (result != null && mounted) {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => TriageSuccessScreen(consultation: result),
                    ),
                  );
                  final auth = context.read<AuthProvider>();
                  await _loadData();
                  _autoNavigateToChat(auth.userId);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: AppTheme.primaryGreen,
              ),
              child: Text(lang.t('Start Now', 'Tangira Nonaha')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveConsultationCard(LanguageProvider lang, ConsultationModel consultation) {
    return InkWell(
      onTap: consultation.status == CareStatus.inProcess
          ? () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => PatientChatScreen(consultation: consultation)),
            )
          : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: consultation.status == CareStatus.pendingPayment
                        ? AppTheme.statusPending.withValues(alpha: 0.1)
                        : consultation.status == CareStatus.inProcess
                            ? AppTheme.statusInProcess.withValues(alpha: 0.1)
                            : AppTheme.statusComplete.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    consultation.status == CareStatus.pendingPayment
                        ? Icons.payment
                        : consultation.status == CareStatus.inProcess
                            ? Icons.chat_rounded
                            : Icons.check_circle_rounded,
                    color: consultation.status == CareStatus.pendingPayment
                        ? AppTheme.statusPending
                        : consultation.status == CareStatus.inProcess
                            ? AppTheme.statusInProcess
                            : AppTheme.statusComplete,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(consultation.statusLabel,
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                      Text('${consultation.biologicalSex} • ${consultation.severityLevel.split('–')[0].trim()}',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
                    ],
                  ),
                ),
                if (consultation.status == CareStatus.pendingPayment)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.statusPending.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text('$_doctorFee RWF',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.statusPending)),
                  ),
              ],
            ),
            if (consultation.status == CareStatus.pendingPayment) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.warningYellow.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.info_rounded, color: AppTheme.warningYellow, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _doctorPhone.isNotEmpty
                            ? lang.t('Send $_doctorFee RWF to $_doctorPhone ($_doctorName${_doctorClinic.isNotEmpty ? " - $_doctorClinic" : ""}) via MoMo (*182#)',
                                'Ohereza $_doctorFee RWF kuri $_doctorPhone ($_doctorName${_doctorClinic.isNotEmpty ? " - $_doctorClinic" : ""}) ukoresheje MoMo (*182#)')
                            : lang.t('Pay $_doctorFee RWF via MoMo (*182#) to continue with $_doctorName',
                                'Ishema $_doctorFee RWF ukoresheje MoMo (*182#) kugirango ukomeze na $_doctorName'),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHistorySection(LanguageProvider lang, List<ConsultationModel> consultations) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(lang.t('Past Consultations', 'Ubuvuzi Bwashize'),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
        const SizedBox(height: 12),
        ...consultations.skip(1).take(5).map((c) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _historyItem(c, lang),
        )),
      ],
    );
  }

  Widget _historyItem(ConsultationModel c, LanguageProvider lang) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PatientChatScreen(consultation: c)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Row(
          children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.document_scanner_rounded, color: AppTheme.primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.severityLevel.split('–')[0].trim(), style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                Text(c.createdAt != null ? '${c.createdAt!.day}/${c.createdAt!.month}/${c.createdAt!.year}' : '',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: c.status == CareStatus.complete
                  ? AppTheme.successGreen.withValues(alpha: 0.1)
                  : AppTheme.warningYellow.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(c.statusLabel, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                color: c.status == CareStatus.complete ? AppTheme.successGreen : AppTheme.warningYellow)),
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildAvatarWidget(String? avatarUrl, double size, {int version = 0}) {
    if (avatarUrl == null) {
      return Icon(Icons.person_rounded, size: size * 0.5, color: AppTheme.primaryGreen);
    }
    if (avatarUrl.startsWith('data:image')) {
      try {
        final b64 = avatarUrl.split(',').last;
        return ClipOval(child: Image.memory(base64Decode(b64), width: size, height: size, fit: BoxFit.cover));
      } catch (_) {}
    }
    return ClipOval(child: Image.network('$avatarUrl?v=$version', width: size, height: size, fit: BoxFit.cover));
  }

  Widget _buildProfileTab(LanguageProvider lang, AuthProvider auth) {
    final picker = ImagePicker();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const SizedBox(height: 20),
          GestureDetector(
            onTap: () async {
              final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
              if (xfile != null && context.mounted) {
                final bytes = await xfile.readAsBytes();
                final err = await auth.uploadAvatar(bytes);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(err == null
                          ? lang.t('Profile photo updated', 'Ifoto ya profili yahinduwe')
                          : lang.t('Failed to update photo', 'Ifoto ntiyahindutse')),
                    ),
                  );
                }
              }
            },
            child: Stack(
              children: [
                _buildAvatarWidget(auth.profile?.avatarUrl, 88, version: auth.avatarVersion),
                Positioned(
                  bottom: 0, right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(auth.profile?.fullName ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
          Text(auth.profile?.phoneNumber ?? '', style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfile(lang, auth),
              icon: const Icon(Icons.edit_rounded),
              label: Text(lang.t('Edit Profile', 'Hindura Profili')),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    (route) => false,
                  );
                }
              },
              icon: const Icon(Icons.logout_rounded),
              label: Text(lang.t('Sign Out', 'Sohoka')),
              style: OutlinedButton.styleFrom(foregroundColor: AppTheme.errorRed, side: const BorderSide(color: AppTheme.errorRed)),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(LanguageProvider lang, AuthProvider auth) {
    final nameController = TextEditingController(text: auth.profile?.fullName ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('Edit Profile', 'Hindura Profili')),
        content: TextField(
          controller: nameController,
          decoration: InputDecoration(labelText: lang.t('Full Name', 'Amazina Yose')),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('Cancel', 'Guhagarika')),
          ),
          TextButton(
            onPressed: () async {
              await auth.updateProfile(fullName: nameController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(lang.t('Save', 'Kubika')),
          ),
        ],
      ),
    );
  }
}
