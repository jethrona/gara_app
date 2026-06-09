import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/constants.dart';
import '../../config/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/consultation_provider.dart';
import '../../providers/language_provider.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/voice_recorder_widget.dart';
import 'prescription_dialog.dart';
import 'transfer_slip_dialog.dart';

class DoctorChatWorkspace extends StatefulWidget {
  final ConsultationModel consultation;
  const DoctorChatWorkspace({super.key, required this.consultation});

  @override
  State<DoctorChatWorkspace> createState() => _DoctorChatWorkspaceState();
}

class _DoctorChatWorkspaceState extends State<DoctorChatWorkspace> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _showTools = false;
  bool _showRecorder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>().loadMessages(widget.consultation.id!);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>();
    final chatProvider = context.watch<ChatProvider>();

    return Scaffold(
      backgroundColor: AppTheme.surfaceBg,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.consultation.patientName ?? 'Patient #${widget.consultation.id}',
                style: const TextStyle(fontSize: 16)),
            Text('${widget.consultation.severityLevel.split("–")[0].trim()} \u2022 ${widget.consultation.biologicalSex}',
                style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_search_rounded),
            tooltip: lang.t('Patient Info', 'Amakuru y\'Umurwayi'),
            onPressed: () => _showPatientInfo(lang),
          ),
          IconButton(
            icon: const Icon(Icons.assignment_rounded),
            tooltip: lang.t('AI Brief', 'Ibisobanuro bya AI'),
            onPressed: () => _showAiBrief(lang),
          ),
          IconButton(
            icon: const Icon(Icons.more_vert_rounded),
            onPressed: () => _showClinicalTools(lang),
          ),
        ],
      ),
      body: Column(
        children: [
          if (!_showTools)
            _buildClinicalToolbar(lang),
          Expanded(
            child: chatProvider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : chatProvider.messages.isEmpty
                    ? _buildEmptyState(lang)
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        itemCount: chatProvider.messages.length,
                        itemBuilder: (context, index) {
                          final msg = chatProvider.messages[index];
                          final isMe = msg.senderId == context.read<AuthProvider>().userId;
                          return ChatBubble(message: msg, isMe: isMe);
                        },
                      ),
          ),
          _buildInputBar(lang),
        ],
      ),
    );
  }

  Widget _buildClinicalToolbar(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.white,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
        children: [
          _toolChip(
            Icons.description_rounded,
            lang.t('Prescribe', 'Kwandika'),
            AppTheme.primaryGreen,
            () => _showPrescriptionDialog(lang),
          ),
          const SizedBox(width: 8),
          _toolChip(
            Icons.transfer_within_a_station_rounded,
            lang.t('Transfer', 'Ihererekanyo'),
            AppTheme.accentOrange,
            () => _showTransferDialog(lang),
          ),
          const SizedBox(width: 8),
          _toolChip(
            Icons.check_circle_rounded,
            lang.t('Complete', 'Byarangiye'),
            AppTheme.successGreen,
            _markComplete,
          ),
          const SizedBox(width: 8),
          _toolChip(
            _showTools ? Icons.close : Icons.build_rounded,
            _showTools ? '' : lang.t('Tools', 'Ibikoresho'),
            AppTheme.textSecondary,
            () => setState(() => _showTools = !_showTools),
          ),
        ],
        ),
      ),
    );
  }

  Widget _toolChip(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: TextStyle(fontSize: 13, color: color, fontWeight: FontWeight.w500)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(LanguageProvider lang) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: AppTheme.primaryGreen.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.chat_rounded, size: 40, color: AppTheme.primaryGreen),
          ),
          const SizedBox(height: 16),
          Text(lang.t('Consultation Active', 'Ubuvuzi Burakora'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(lang.t('Start the conversation with your patient', 'Tangira ikiganiro n\'umurwayi'),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
        ],
      ),
    );
  }

  Widget _buildInputBar(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: SafeArea(
        child: _showRecorder
            ? Row(
                children: [
                  Expanded(
                    child: VoiceRecorderWidget(
                      onSend: (bytes, duration) async {
                        await _sendVoice(bytes, duration);
                        setState(() => _showRecorder = false);
                      },
                      onCancel: () => setState(() => _showRecorder = false),
                    ),
                  ),
                ],
              )
            : Row(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceBg,
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image_rounded, color: AppTheme.textSecondary),
                          onPressed: () => _pickImage(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic_rounded, color: AppTheme.textSecondary),
                          onPressed: () => setState(() => _showRecorder = true),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: lang.t('Type a message...', 'Andika ubutumwa...'),
                        border: InputBorder.none,
                        filled: true,
                        fillColor: AppTheme.surfaceBg,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    decoration: const BoxDecoration(
                      color: AppTheme.primaryGreen,
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                      onPressed: _sendMessage,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final chatProvider = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();
    chatProvider.sendTextMessage(
      consultationId: widget.consultation.id!,
      senderId: auth.userId,
      content: text,
    );
    _messageController.clear();
    _scrollToBottom();
  }

  Future<void> _pickImage() async {
    final xfile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 25);
    if (xfile == null) return;
    final bytes = await xfile.readAsBytes();

    final chatProvider = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();
    final err = await chatProvider.uploadAndSendImage(
      consultationId: widget.consultation.id!,
      senderId: auth.userId,
      imageBytes: bytes,
    );
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Image failed: $err')),
      );
    }
    _scrollToBottom();
  }

  Future<void> _sendVoice(Uint8List voiceBytes, int duration) async {
    final chatProvider = context.read<ChatProvider>();
    final auth = context.read<AuthProvider>();
    final err = await chatProvider.uploadAndSendVoice(
      consultationId: widget.consultation.id!,
      senderId: auth.userId,
      voiceBytes: voiceBytes,
      durationSeconds: duration,
    );
    if (err != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Voice note failed: $err')),
      );
    }
    _scrollToBottom();
  }

  void _showPatientInfo(LanguageProvider lang) {
    final c = widget.consultation;
    final severityKey = c.severityLevel.split('–')[0].trim();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('Patient Information', 'Amakuru y\'Umurwayi')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _infoRow(lang.t('Name', 'Izina'), c.patientName ?? '—'),
              const Divider(),
              _infoRow(lang.t('Biological Sex', 'Igitsina'), lang.t(c.biologicalSex, AppConstants.biologicalSexRw[c.biologicalSex] ?? c.biologicalSex)),
              const Divider(),
              _infoRow(lang.t('Severity', 'Uburemere'), lang.t(severityKey, AppConstants.severityRw[severityKey] ?? severityKey)),
              const Divider(),
              if (c.symptomCategory != null) ...[
                _infoRow(lang.t('Category', 'Icyiciro'), lang.t(c.symptomCategory!, AppConstants.symptomCategoryRw[c.symptomCategory!] ?? c.symptomCategory!)),
                const Divider(),
              ],
              if (c.symptomDescription != null && c.symptomDescription!.isNotEmpty) ...[
                _infoRow(lang.t('Description', 'Ibisobanuro'), c.symptomDescription!),
                const Divider(),
              ],
              if (c.aiBriefSummary != null) ...[
                Text(lang.t('AI Clinical Brief', 'Incamake ya AI'),
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                const SizedBox(height: 4),
                Text(c.aiBriefSummary!, style: const TextStyle(fontSize: 12, height: 1.4)),
                const Divider(),
              ],
              _infoRow(lang.t('Duration', 'Igihe'), lang.t(c.durationSymptoms, AppConstants.durationRw[c.durationSymptoms] ?? c.durationSymptoms)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('Close', 'Funga'))),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _showAiBrief(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(lang.t('AI Clinical Brief', 'Ibisobanuro bya AI')),
        content: SingleChildScrollView(
          child: Text(
            widget.consultation.aiBriefSummary ?? lang.t('No AI brief available.', 'Nta bisobanuro bihari.'),
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(lang.t('Close', 'Funga'))),
        ],
      ),
    );
  }

  void _showClinicalTools(LanguageProvider lang) {
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
              Text(lang.t('Clinical Actions', 'Ibikorwa by\'Ubuvuzi'),
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.description_rounded, color: AppTheme.primaryGreen),
                ),
                title: Text(lang.t('Generate Prescription', 'Kwandika Imiti')),
                subtitle: Text(lang.t('Create a digital prescription PDF', 'Kora dosiye ya PDF')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showPrescriptionDialog(lang);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.accentOrange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.transfer_within_a_station_rounded, color: AppTheme.accentOrange),
                ),
                title: Text(lang.t('Generate Transfer Slip', 'Kora Inyandiko y\'Ihererekanyo')),
                subtitle: Text(lang.t('Create official hospital referral', 'Kora referral ya kuvuriro')),
                onTap: () {
                  Navigator.pop(ctx);
                  _showTransferDialog(lang);
                },
              ),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppTheme.successGreen.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: AppTheme.successGreen),
                ),
                title: Text(lang.t('Mark as Complete', 'Shyira Akamenyetso ko Byarangiye')),
                subtitle: Text(lang.t('Close this consultation', 'Funga ubu buvuzi')),
                onTap: () {
                  Navigator.pop(ctx);
                  _markComplete();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPrescriptionDialog(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (_) => PrescriptionDialog(
        consultation: widget.consultation,
      ),
    );
  }

  void _showTransferDialog(LanguageProvider lang) {
    showDialog(
      context: context,
      builder: (_) => TransferSlipDialog(
        consultation: widget.consultation,
      ),
    );
  }

  void _markComplete() {
    final provider = context.read<ConsultationProvider>();
    provider.updateConsultationStatus(widget.consultation.id!, CareStatus.complete);
    Navigator.pop(context);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }
}
