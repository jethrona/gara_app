import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/consultation_model.dart';
import '../../models/notification_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/language_provider.dart';
import '../../providers/notification_provider.dart';
import '../../widgets/consultation_card.dart';
import '../../widgets/financial_ticker.dart';
import '../../widgets/language_toggle.dart';
import 'doctor_chat_workspace.dart';
import '../auth/onboarding_screen.dart';

class DoctorDashboard extends StatefulWidget {
  const DoctorDashboard({super.key});

  @override
  State<DoctorDashboard> createState() => _DoctorDashboardState();
}

class _DoctorDashboardState extends State<DoctorDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isConfirmingPayment = false;
  final Set<int> _confirmedPaymentIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _initDoctor();
  }

  void _initDoctor() {
    final consultationProvider = context.read<ConsultationProvider>();
    final notifProvider = context.read<NotificationProvider>();
    final auth = context.read<AuthProvider>();
    consultationProvider.loadDoctorQueues();
    consultationProvider.startRealtimeListener();
    if (auth.profile != null) {
      notifProvider.init(auth.userId);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final consultationProvider = context.watch<ConsultationProvider>();
    final auth = context.watch<AuthProvider>();
    final notifProvider = context.watch<NotificationProvider>();
    final stats = consultationProvider.doctorStats;

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Text(lang.t('Doctor Panel', 'Ikibaho cy\'Umuganga')),
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
      drawer: _buildDrawer(lang, auth),
      body: RefreshIndicator(
        onRefresh: () => consultationProvider.loadDoctorQueues(),
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildFinancialTickers(lang, stats)),
            SliverToBoxAdapter(child: _buildTabBar(lang, consultationProvider)),
            SliverFillRemaining(child: _buildTabContent(lang, consultationProvider)),
          ],
        ),
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
                                  _handleNotificationTap(n, lang);
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

  void _handleNotificationTap(NotificationModel n, LanguageProvider lang) {
    if (n.consultationId != null) {
      final allConsultations = [
        ...context.read<ConsultationProvider>().inProcess,
        ...context.read<ConsultationProvider>().pendingPayments,
      ];
      final consultation = allConsultations
          .where((c) => c.id == n.consultationId)
          .firstOrNull;
      if (consultation != null) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DoctorChatWorkspace(consultation: consultation)),
        );
        return;
      }
    }
  }

  Widget _buildDrawer(LanguageProvider lang, AuthProvider auth) {
    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppTheme.primaryGreen, AppTheme.primaryGreenDark],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDrawerAvatar(auth.profile?.avatarUrl, 60, version: auth.avatarVersion),
                  const SizedBox(height: 12),
                  Text(auth.profile?.fullName ?? '',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  if (auth.profile?.clinicName != null && auth.profile!.clinicName!.isNotEmpty)
                    Text(auth.profile!.clinicName!,
                        style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                  Text(auth.profile?.phoneNumber ?? '',
                      style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.6))),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dashboard_rounded, color: AppTheme.primaryGreen),
              title: Text(lang.t('Dashboard', 'Ikibaho')),
              selected: true,
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: AppTheme.textSecondary),
              title: Text(lang.t('Profile', 'Profili')),
              onTap: () {
                Navigator.pop(context);
                _showEditProfile(lang);
              },
            ),
            ListTile(
              leading: const Icon(Icons.tune_rounded, color: AppTheme.textSecondary),
              title: Text(lang.t('Settings', 'Igenamiterere')),
              onTap: () {
                Navigator.pop(context);
                _showSettings(lang);
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout_rounded, color: AppTheme.errorRed),
              title: Text(lang.t('Sign Out', 'Sohoka')),
              onTap: () async {
                await auth.signOut();
                if (context.mounted) {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                    (route) => false,
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerAvatar(String? avatarUrl, double size, {int version = 0}) {
    if (avatarUrl == null) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
        child: const Icon(Icons.medical_information_rounded, color: Colors.white, size: 32),
      );
    }
    if (avatarUrl.startsWith('data:image')) {
      try {
        final b64 = avatarUrl.split(',').last;
        return ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.memory(base64Decode(b64), width: size, height: size, fit: BoxFit.cover));
      } catch (_) {}
    }
    return ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.network('$avatarUrl?v=$version', width: size, height: size, fit: BoxFit.cover));
  }

  Widget _buildAvatarWidget(String? avatarUrl, double size, {int version = 0}) {
    if (avatarUrl == null) {
      return const Icon(Icons.camera_alt, size: 32, color: AppTheme.textMuted);
    }
    if (avatarUrl.startsWith('data:image')) {
      try {
        final b64 = avatarUrl.split(',').last;
        return CircleAvatar(radius: size / 2, backgroundImage: MemoryImage(base64Decode(b64)));
      } catch (_) {}
    }
    return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage('$avatarUrl?v=$version'));
  }

  void _showEditProfile([LanguageProvider? lang]) {
    final auth = context.read<AuthProvider>();
    final nameController = TextEditingController(text: auth.profile?.fullName ?? '');
    final picker = ImagePicker();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang?.t('Edit Profile', 'Hindura Profili') ?? 'Edit Profile'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () async {
                final xfile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);
                if (xfile != null && ctx.mounted) {
                  final bytes = await xfile.readAsBytes();
                  final err = await auth.uploadAvatar(bytes);
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(
                        content: Text(err == null
                            ? (lang?.t('Profile photo updated', 'Ifoto ya profili yahinduwe') ?? 'Profile photo updated')
                            : (lang?.t('Failed to update photo', 'Ifoto ntiyahindutse') ?? 'Failed to update photo')),
                      ),
                    );
                  }
                }
              },
              child: _buildAvatarWidget(auth.profile?.avatarUrl, 72, version: auth.avatarVersion),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: InputDecoration(labelText: lang?.t('Full Name', 'Amazina Yose') ?? 'Full Name'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang?.t('Cancel', 'Guhagarika') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await auth.updateProfile(fullName: nameController.text.trim());
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(lang?.t('Save', 'Kubika') ?? 'Save'),
          ),
        ],
      ),
    );
  }

  void _showSettings([LanguageProvider? lang]) {
    final auth = context.read<AuthProvider>();
    final feeController = TextEditingController(text: auth.profile != null ? '${auth.profile!.consultationFee}' : '2000');
    final nameController = TextEditingController(text: auth.profile?.fullName ?? '');
    final clinicController = TextEditingController(text: auth.profile?.clinicName ?? '');
    final phoneController = TextEditingController(text: auth.profile?.phoneNumber ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang?.t('Practice Settings', 'Igenamiterere ry\'Ubuvuzi') ?? 'Practice Settings'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: feeController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: lang?.t('Consultation Fee (RWF)', 'Amafaranga y\'Ubuvuzi (RWF)') ?? 'Consultation Fee (RWF)',
                  prefixIcon: const Icon(Icons.monetization_on_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: lang?.t('Display Name', 'Amazina Agaragara') ?? 'Display Name',
                  prefixIcon: const Icon(Icons.person_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: clinicController,
                decoration: InputDecoration(
                  labelText: lang?.t('Clinic Name', 'Izina ry\'Ivuriro') ?? 'Clinic Name',
                  hintText: lang?.t('e.g. GARA Health Center', 'Urugero: Ivuriro rya GARA') ?? 'e.g. GARA Health Center',
                  prefixIcon: const Icon(Icons.local_hospital_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: lang?.t('MoMo Phone Number', 'Nomero ya MoMo') ?? 'MoMo Phone Number',
                  hintText: lang?.t('e.g. 0788123456', 'Urugero: 0788123456') ?? 'e.g. 0788123456',
                  prefixIcon: const Icon(Icons.phone_rounded),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang?.t('Cancel', 'Guhagarika') ?? 'Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final fee = int.tryParse(feeController.text.trim()) ?? 2000;
              final clinicText = clinicController.text.trim();
              await auth.updateDoctorSettings(
                consultationFee: fee,
                fullName: nameController.text.trim(),
                clinicName: clinicText.isNotEmpty ? clinicText : null,
                phoneNumber: phoneController.text.trim(),
              );
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(lang?.t('Save', 'Kubika') ?? 'Save'),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialTickers(LanguageProvider lang, Map<String, dynamic> stats) {
    final todayIncome = (stats['todayIncome'] as double?) ?? 0.0;
    final monthlyIncome = (stats['monthlyIncome'] as double?) ?? 0.0;
    final totalPatients = (stats['totalPatients'] as int?) ?? 0;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(lang.t('Financial Overview', 'Reba Amafaranga'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FinancialTicker(
                  label: lang.t("Today's Income", 'Amafaranga Y\'Uyu Munsi'),
                  amount: todayIncome,
                  icon: Icons.trending_up_rounded,
                  color: AppTheme.successGreen,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FinancialTicker(
                  label: lang.t('Monthly Income', 'Amafaranga Y\'Uku Kwezi'),
                  amount: monthlyIncome,
                  icon: Icons.calendar_month_rounded,
                  color: AppTheme.accentBlue,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.people_rounded, color: AppTheme.primaryGreen, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(lang.t('Total Patients (Confirmed)', 'Indwara Zose (Zemejwe)')),
                      Text('$totalPatients',
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppTheme.textMuted),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar(LanguageProvider lang, ConsultationProvider provider) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: TabBar(
        controller: _tabController,
        onTap: (_) => setState(() {}),
        tabs: [
          Tab(text: '${lang.t("Payments", "Amafaranga")} (${provider.pendingPayments.length})'),
          Tab(text: '${lang.t("Active", "Igikora")} (${provider.inProcess.length})'),
          Tab(text: '${lang.t("Complete", "Byarangiye")} (${provider.completed.length})'),
        ],
      ),
    );
  }

  Widget _buildTabContent(LanguageProvider lang, ConsultationProvider provider) {
    return TabBarView(
      controller: _tabController,
      children: [
        _buildQueueList(lang, provider.pendingPayments, CareStatus.pendingPayment),
        _buildQueueList(lang, provider.inProcess, CareStatus.inProcess),
        _buildQueueList(lang, provider.completed, CareStatus.complete),
      ],
    );
  }

  Widget _buildQueueList(LanguageProvider lang, List<ConsultationModel> items, CareStatus status) {
    final consultationProvider = context.read<ConsultationProvider>();
    if (consultationProvider.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              status == CareStatus.pendingPayment
                  ? Icons.payments_rounded
                  : status == CareStatus.inProcess
                      ? Icons.chat_rounded
                      : Icons.check_circle_rounded,
              size: 48,
              color: AppTheme.textMuted,
            ),
            const SizedBox(height: 12),
            Text(
              status == CareStatus.pendingPayment
                  ? lang.t('No pending payments', 'Nta mafaranga ategejeje')
                  : status == CareStatus.inProcess
                      ? lang.t('No active consultations', 'Nta buvuzi bukora')
                      : lang.t('No completed consultations', 'Nta buvuzi bwarangiye'),
              style: const TextStyle(fontSize: 16, color: AppTheme.textMuted),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final consultation = items[index];
        return ConsultationCard(
          consultation: consultation,
          onTap: () {
            if (status == CareStatus.pendingPayment) {
              _showPendingPaymentOptions(consultation);
            } else if (status == CareStatus.inProcess) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DoctorChatWorkspace(consultation: consultation)),
              ).then((_) {
                context.read<ConsultationProvider>().loadDoctorQueues();
              });
            } else {
              _showCompletedDetails(consultation);
            }
          },
          trailing: status == CareStatus.inProcess
              ? IconButton(
                  icon: const Icon(Icons.check_circle_outline_rounded, color: AppTheme.primaryGreen),
                  tooltip: lang.t('Mark Complete', 'Rangiza'),
                  onPressed: () => _confirmMarkComplete(consultation, lang),
                )
              : null,
        );
      },
    );
  }

  void _confirmMarkComplete(ConsultationModel consultation, LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('Mark as Complete?', 'Rangiza Ubuvuzi?')),
        content: Text(lang.t(
          'This will end the consultation for ${consultation.patientName ?? "this patient"}. Make sure you have sent all prescriptions and referrals.',
          'Ibi bizarangiza ubuvuzi bwa ${consultation.patientName ?? "uyu murwayi"}. Reba ko watanze ibiyandiko byose.',
        )),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(lang.t('Cancel', 'Guhagarika')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
            onPressed: () async {
              Navigator.pop(ctx);
              await context.read<ConsultationProvider>().markConsultationComplete(
                consultation.id!,
                patientId: consultation.patientId,
              );
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(lang.t('Consultation marked as complete.', 'Ubuvuzi bwarangiye.')),
                  backgroundColor: AppTheme.primaryGreen,
                ));
              }
            },
            child: Text(lang.t('Confirm', 'Emeza'), style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _showPaymentVerification(ConsultationModel consultation) {
    final lang = context.read<LanguageProvider>();
    if (_confirmedPaymentIds.contains(consultation.id)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(lang.t('Payment already confirmed for this consultation.', 'Amafaranga yasemejwe kuri ubu buvuzi.')),
      ));
      return;
    }

    final auth = context.read<AuthProvider>();
    final transactionController = TextEditingController();
    final profileFee = auth.profile?.consultationFee ?? AppConstants.consultationFee;
    final amountController = TextEditingController(text: profileFee.toString());

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
          padding: EdgeInsets.only(
            left: 24, right: 24, top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(lang.t('Verify Payment', 'Emeza Amafaranga'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${lang.t("Patient:", "Umurwayi:")} ${consultation.patientName ?? lang.t("Unknown", "Ntazwi")}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 20),
              TextField(
                controller: amountController,
                readOnly: true,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: lang.t('Amount (RWF)', 'Amafaranga (RWF)'),
                  prefixIcon: const Icon(Icons.monetization_on_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: transactionController,
                decoration: InputDecoration(
                  labelText: lang.t('MoMo Transaction Ref (optional)', 'Ref y\'ihererekanywa (bishoboka)'),
                  prefixIcon: const Icon(Icons.receipt_rounded),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isConfirmingPayment
                      ? null
                      : () async {
                          setSheetState(() => _isConfirmingPayment = true);
                          try {
                            final provider = context.read<ConsultationProvider>();
                            final updated = await provider.verifyPayment(
                              consultationId: consultation.id!,
                              transactionId: transactionController.text.trim(),
                              amount: double.tryParse(amountController.text) ?? profileFee.toDouble(),
                              patientId: consultation.patientId,
                              patientName: consultation.patientName,
                            );
                            if (updated) {
                              setState(() => _confirmedPaymentIds.add(consultation.id!));
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(lang.t(
                                    'Payment confirmed. Patient moved to Active.',
                                    'Amafaranga yemejwe. Umurwayi yimurirwa mu Bakora.',
                                  )),
                                  backgroundColor: AppTheme.primaryGreen,
                                ));
                              }
                            } else {
                              if (ctx.mounted) {
                                Navigator.pop(ctx);
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: Text(lang.t(
                                    'Payment was already confirmed.',
                                    'Amafaranga yari yasemejwe.',
                                  )),
                                ));
                              }
                            }
                          } finally {
                            if (mounted) setState(() => _isConfirmingPayment = false);
                          }
                        },
                  child: _isConfirmingPayment
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(lang.t('Confirm Payment', 'Emeza Amafaranga')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPendingPaymentOptions(ConsultationModel consultation) {
    final lang = context.read<LanguageProvider>();
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Text(lang.t('Pending Payment', 'Amafaranga Ategejeje'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('${consultation.patientName ?? "Unknown"}',
                  style: const TextStyle(color: AppTheme.textSecondary)),
              const SizedBox(height: 24),
              if (_confirmedPaymentIds.contains(consultation.id))
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
                      const SizedBox(width: 8),
                      Text(lang.t('Payment already confirmed this session.',
                          'Amafaranga yasemejwe muri iyi seansyo.')),
                    ],
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _showPaymentVerification(consultation);
                    },
                    icon: const Icon(Icons.payments_rounded),
                    label: Text(lang.t('Verify Payment', 'Emeza Amafaranga')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DoctorChatWorkspace(consultation: consultation),
                      ),
                    );
                  },
                  icon: const Icon(Icons.chat_rounded),
                  label: Text(lang.t('View Messages', 'Reba Ubutumwa')),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCompletedDetails(ConsultationModel consultation) {
    final lang2 = context.read<LanguageProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${lang2.t('Consultation', 'Ubuvuzi')} #${consultation.id}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${lang2.t('Patient:', 'Umurwayi:')} ${consultation.patientName ?? lang2.t('Unknown', 'Ntazwi')}'),
            Text('${lang2.t('Sex:', 'Igitsina:')} ${lang2.t(consultation.biologicalSex, AppConstants.biologicalSexRw[consultation.biologicalSex] ?? consultation.biologicalSex)}'),
            Text('${lang2.t('Severity:', 'Uburemere:')} ${lang2.t(consultation.severityLevel.split('–')[0].trim(), AppConstants.severityRw[consultation.severityLevel.split('–')[0].trim()] ?? consultation.severityLevel.split('–')[0].trim())}'),
            if (consultation.symptomCategory != null)
              Text('${lang2.t('Category:', 'Icyiciro:')} ${lang2.t(consultation.symptomCategory!, AppConstants.symptomCategoryRw[consultation.symptomCategory!] ?? consultation.symptomCategory!)}'),
            if (consultation.symptomDescription != null && consultation.symptomDescription!.isNotEmpty)
              Text('${lang2.t('Description:', 'Ibisobanuro:')} ${consultation.symptomDescription}'),
            Text('${lang2.t('Amount:', 'Amafaranga:')} ${consultation.paymentAmount} RWF'),
            if (consultation.aiBriefSummary != null) ...[
              const SizedBox(height: 8),
              Text(lang2.t('AI Brief:', 'AI Incamake:'), style: const TextStyle(fontWeight: FontWeight.w600)),
              Text(consultation.aiBriefSummary!, style: const TextStyle(fontSize: 12)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang2.t('Close', 'Funga'))),
        ],
      ),
    );
  }
}
