import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/language_toggle.dart';
import '../../widgets/status_tracker_card.dart';
import 'triage_form.dart';
import 'patient_chat_screen.dart';
import 'documents_screen.dart';
import '../auth/onboarding_screen.dart';

class PatientDashboard extends StatefulWidget {
  const PatientDashboard({super.key});

  @override
  State<PatientDashboard> createState() => _PatientDashboardState();
}

class _PatientDashboardState extends State<PatientDashboard> {
  int _currentTab = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    final auth = context.read<AuthProvider>();
    final consultationProvider = context.read<ConsultationProvider>();
    final notifProvider = context.read<NotificationProvider>();
    if (auth.profile != null) {
      consultationProvider.loadPatientConsultations(auth.profile!.id);
      notifProvider.init(auth.profile!.id);
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
    final notifProvider = context.read<NotificationProvider>();
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
        builder: (_, scrollController) => Padding(
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
                              Icons.info_rounded,
                              color: n.isRead ? AppTheme.textMuted : AppTheme.primaryGreen,
                            ),
                            title: Text(n.title, style: TextStyle(fontWeight: n.isRead ? FontWeight.w400 : FontWeight.w600)),
                            subtitle: Text(n.body, style: const TextStyle(fontSize: 12)),
                            trailing: n.isRead ? null : Container(width: 8, height: 8, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.primaryGreen)),
                            onTap: () {
                              if (n.id != null) notifProvider.markAsRead(n.id!);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboard(LanguageProvider lang, ConsultationModel? active,
      int pendingCount, int inProcessCount, int completedCount) {
    final consultationProvider = context.read<ConsultationProvider>();
    return RefreshIndicator(
      onRefresh: () async => _loadData(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (active != null) StatusTrackerCard(consultation: active),
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
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TriageForm()),
              ),
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
                    child: Text('${AppConstants.consultationFee.toInt()} RWF',
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
                        lang.t('Send 2,000 RWF to ${AppConstants.momoNumber} via MoMo (*182#)',
                            'Ohereza 2,000 RWF kuri ${AppConstants.momoNumber} ukoresheje MoMo (*182#)'),
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
    return Container(
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
    );
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
              final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
              if (file != null) {
                await auth.uploadAvatar(File(file.path));
              }
            },
            child: Stack(
              children: [
                Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    image: auth.profile?.avatarUrl != null
                        ? DecorationImage(image: NetworkImage(auth.profile!.avatarUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: auth.profile?.avatarUrl == null
                      ? const Icon(Icons.person_rounded, size: 44, color: AppTheme.primaryGreen)
                      : null,
                ),
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
