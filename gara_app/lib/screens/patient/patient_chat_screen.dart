import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/consultation_model.dart';
import '../../providers/appointment_provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/chat_provider.dart';
import '../../providers/language_provider.dart';
import '../../services/supabase_service.dart';
import '../../widgets/chat_bubble.dart';
import '../../widgets/voice_recorder_widget.dart';

class PatientChatScreen extends StatefulWidget {
  final ConsultationModel consultation;
  const PatientChatScreen({super.key, required this.consultation});

  @override
  State<PatientChatScreen> createState() => _PatientChatScreenState();
}

class _PatientChatScreenState extends State<PatientChatScreen> {
  final _messageController = TextEditingController();
  final _scrollController = ScrollController();
  final _picker = ImagePicker();
  bool _showRecorder = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chatProvider = context.read<ChatProvider>();
      chatProvider.loadMessages(widget.consultation.id!);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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
            Text(lang.t('Consultation', 'Ubuvuzi')),
            Text('#${widget.consultation.id}',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted, fontWeight: FontWeight.w400)),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.statusInProcess.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(lang.t('Active', 'Igikora'),
                style: const TextStyle(fontSize: 12, color: AppTheme.statusInProcess, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: Column(
        children: [
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
                          return ChatBubble(
                            message: msg,
                            isMe: isMe,
                          );
                        },
                      ),
          ),
          widget.consultation.status == CareStatus.complete
              ? _buildCompletedBanner(lang)
              : _buildInputBar(lang),
        ],
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
          Text(lang.t('Start your conversation', 'Tangira ikiganiro'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(lang.t('Send a message to your doctor', 'Ohereza ubutumwa kuri muganga wawe'),
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
                        IconButton(
                          icon: const Icon(Icons.calendar_month_rounded, color: AppTheme.textSecondary),
                          onPressed: () => _showBookAppointment(lang),
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

  Widget _buildCompletedBanner(LanguageProvider lang) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: AppTheme.surfaceBg,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_rounded, size: 16, color: AppTheme.textMuted),
              const SizedBox(width: 8),
              Expanded(
                child: Text(lang.t('This consultation is completed. Chat is read-only.', 'Ubu buvuzi burarangiye. Ushobora gusoma gusa.'),
                    style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showBookAppointment(lang),
              icon: const Icon(Icons.calendar_month_rounded, size: 18),
              label: Text(lang.t('Book a Follow-up Appointment', 'Gufata appointment yo gukurikirana')),
            ),
          ),
        ],
      ),
    );
  }

  void _showBookAppointment(LanguageProvider lang) {
    DateTime selectedDate = DateTime.now().add(const Duration(days: 1));
    TimeOfDay selectedTime = const TimeOfDay(hour: 10, minute: 0);
    final notesController = TextEditingController();

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
              Text(lang.t('Book Appointment', 'Gufata Appointment'),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              ListTile(
                leading: const Icon(Icons.calendar_today_rounded),
                title: Text(lang.t('Date', 'Itariki')),
                subtitle: Text('${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}'),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 90)),
                  );
                  if (picked != null) setSheetState(() => selectedDate = picked);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time_rounded),
                title: Text(lang.t('Time', 'Isaha')),
                subtitle: Text(selectedTime.format(context)),
                trailing: const Icon(Icons.edit_rounded),
                onTap: () async {
                  final picked = await showTimePicker(
                    context: ctx,
                    initialTime: selectedTime,
                  );
                  if (picked != null) setSheetState(() => selectedTime = picked);
                },
              ),
              TextField(
                controller: notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  hintText: lang.t('Optional notes...', 'Ibisobanuro by\'inyongera...'),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    final auth = context.read<AuthProvider>();
                    final appointmentProvider = context.read<AppointmentProvider>();
                    final doctorResponse = await SupabaseService().client
                        .from('profiles')
                        .select('id')
                        .eq('is_doctor', true)
                        .limit(1)
                        .maybeSingle();
                    final doctorId = doctorResponse?['id'] as String?;
                    if (doctorId == null) {
                      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(lang.t('Doctor not found.', 'Muganga ntiyabonetse.')),
                      ));
                      return;
                    }
                    final combined = DateTime(
                      selectedDate.year, selectedDate.month, selectedDate.day,
                      selectedTime.hour, selectedTime.minute,
                    );
                    await appointmentProvider.requestAppointment(
                      patientId: auth.userId,
                      doctorId: doctorId,
                      requestedDate: combined,
                      notes: notesController.text.trim().isEmpty ? null : notesController.text.trim(),
                      onSuccess: () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(lang.t('Appointment requested!', 'Appointment yasabwe!')),
                            backgroundColor: AppTheme.primaryGreen,
                          ));
                        }
                      },
                    );
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text(lang.t('Request Appointment', 'Saba Appointment')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
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
}
