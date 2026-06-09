import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/consultation_model.dart';

class ConsultationCard extends StatelessWidget {
  final ConsultationModel consultation;
  final VoidCallback onTap;
  final Widget? trailing;
  final bool isReturning;

  const ConsultationCard({
    super.key,
    required this.consultation,
    required this.onTap,
    this.trailing,
    this.isReturning = false,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor;
    final IconData statusIcon;

    switch (consultation.status) {
      case CareStatus.pendingPayment:
        statusColor = AppTheme.statusPending;
        statusIcon = Icons.payments_rounded;
        break;
      case CareStatus.inProcess:
        statusColor = AppTheme.statusInProcess;
        statusIcon = Icons.chat_rounded;
        break;
      case CareStatus.complete:
        statusColor = AppTheme.statusComplete;
        statusIcon = Icons.check_circle_rounded;
        break;
    }

    final severity = consultation.severityLevel.split('–')[0].trim();
    final severityColor = severity == 'Severe'
        ? AppTheme.errorRed
        : severity == 'Moderate'
            ? AppTheme.accentOrange
            : AppTheme.successGreen;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(statusIcon, color: statusColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          consultation.patientName ?? 'Patient #${consultation.id}',
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: severityColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            severity,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: severityColor),
                          ),
                        ),
                        if (isReturning) ...[
                          const SizedBox(width: 4),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.accentBlue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'Returning',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppTheme.accentBlue),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(consultation.biologicalSex,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                        const SizedBox(width: 8),
                        Text(consultation.durationSymptoms.length > 20
                            ? '${consultation.durationSymptoms.substring(0, 20)}...'
                            : consultation.durationSymptoms,
                            style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                      ],
                    ),
                    if (consultation.paymentAmount > 0) ...[
                      const SizedBox(height: 4),
                      Text('${consultation.paymentAmount.toStringAsFixed(0)} RWF',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.successGreen)),
                    ],
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          consultation.statusLabel,
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: statusColor),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        consultation.createdAt != null
                            ? '${consultation.createdAt!.hour.toString().padLeft(2, '0')}:${consultation.createdAt!.minute.toString().padLeft(2, '0')}'
                            : '',
                        style: const TextStyle(fontSize: 10, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                  if (trailing != null) ...[
                    const SizedBox(width: 4),
                    trailing!,
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
