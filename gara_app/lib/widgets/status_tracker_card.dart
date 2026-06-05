import 'package:flutter/material.dart';
import '../config/constants.dart';
import '../config/theme.dart';
import '../models/consultation_model.dart';

class StatusTrackerCard extends StatelessWidget {
  final ConsultationModel consultation;
  final String doctorName;
  final String doctorPhone;
  final int doctorFee;
  const StatusTrackerCard({
    super.key,
    required this.consultation,
    this.doctorName = 'Doctor',
    this.doctorPhone = '',
    this.doctorFee = 2000,
  });

  @override
  Widget build(BuildContext context) {
    final steps = [
      _StepData('Triage', Icons.assignment_rounded, CareStatus.pendingPayment, consultation.status, AppTheme.primaryGreen),
      _StepData('Payment', Icons.payments_rounded, CareStatus.pendingPayment, consultation.status, AppTheme.accentOrange),
      _StepData('Consult', Icons.chat_rounded, CareStatus.inProcess, consultation.status, AppTheme.accentBlue),
      _StepData('Done', Icons.check_circle_rounded, CareStatus.complete, consultation.status, AppTheme.successGreen),
    ];

    int activeStep = 0;
    switch (consultation.status) {
      case CareStatus.pendingPayment:
        activeStep = 1;
        break;
      case CareStatus.inProcess:
        activeStep = 2;
        break;
      case CareStatus.complete:
        activeStep = 3;
        break;
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                  color: _getStatusColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(consultation.statusLabel,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: _getStatusColor())),
                  Text(consultation.severityLevel.split('–')[0].trim(),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: List.generate(steps.length, (i) {
              final step = steps[i];
              final isCompleted = i < activeStep;
              final isActive = i == activeStep;

              return Expanded(
                child: Column(
                  children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isCompleted
                            ? step.activeColor
                            : isActive
                                ? step.activeColor.withValues(alpha: 0.15)
                                : AppTheme.borderLight,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: isCompleted
                            ? const Icon(Icons.check, color: Colors.white, size: 18)
                            : Icon(step.icon, color: isActive ? step.activeColor : AppTheme.textMuted, size: 16),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(step.label, style: TextStyle(fontSize: 10, color: isActive || isCompleted ? AppTheme.textPrimary : AppTheme.textMuted)),
                  ],
                ),
              );
            }),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (activeStep) / 3,
              backgroundColor: AppTheme.borderLight,
              valueColor: AlwaysStoppedAnimation<Color>(_getStatusColor()),
              minHeight: 4,
            ),
          ),
          if (consultation.status == CareStatus.pendingPayment) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningYellow.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warningYellow.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_rounded, color: AppTheme.warningYellow, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Send $doctorFee RWF to $doctorPhone ($doctorName) via *182#',
                      style: const TextStyle(fontSize: 12, color: AppTheme.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (consultation.status == CareStatus.inProcess) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.statusInProcess.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.statusInProcess.withValues(alpha: 0.2)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.chat_rounded, color: AppTheme.statusInProcess, size: 18),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Tap to enter the consultation chat room',
                        style: TextStyle(fontSize: 12, color: AppTheme.textPrimary)),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Color _getStatusColor() {
    switch (consultation.status) {
      case CareStatus.pendingPayment:
        return AppTheme.statusPending;
      case CareStatus.inProcess:
        return AppTheme.statusInProcess;
      case CareStatus.complete:
        return AppTheme.statusComplete;
    }
  }

  IconData _getStatusIcon() {
    switch (consultation.status) {
      case CareStatus.pendingPayment:
        return Icons.payments_rounded;
      case CareStatus.inProcess:
        return Icons.chat_rounded;
      case CareStatus.complete:
        return Icons.check_circle_rounded;
    }
  }
}

class _StepData {
  final String label;
  final IconData icon;
  final CareStatus stepStatus;
  final CareStatus currentStatus;
  final Color activeColor;

  _StepData(this.label, this.icon, this.stepStatus, this.currentStatus, this.activeColor);
}
