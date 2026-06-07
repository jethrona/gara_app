import 'consultation_service.dart';

class SmsService {
  final ConsultationService _consultationService = ConsultationService();

  static final RegExp _amountRegex = RegExp(r'(\d+[,.]?\d*)\s*RWF', caseSensitive: false);
  static final RegExp _refRegex = RegExp(r'(?:Ref|Transaction|ID)[:\s]*([A-Z0-9]+)', caseSensitive: false);

  void Function(Map<String, dynamic>)? onPaymentDetected;

  void startListening() {
    // SMS auto-detection requires a native Android plugin.
    // For now, payments are verified manually by the doctor
    // via the payment verification modal in the doctor dashboard.
  }

  void stopListening() {}

  Future<bool> processManualPayment({
    required int consultationId,
    required String smsBody,
  }) async {
    try {
      final amountMatch = _amountRegex.firstMatch(smsBody);
      final refMatch = _refRegex.firstMatch(smsBody);

      if (amountMatch == null || refMatch == null) return false;

      final amount = double.parse(amountMatch.group(1)!.replaceAll(',', ''));
      final ref = refMatch.group(1)!;

      final paymentData = {
        'amount': amount,
        'transaction_ref': ref,
        'raw_sms': smsBody,
        'timestamp': DateTime.now().toIso8601String(),
      };

      await _consultationService.verifyPayment(
        consultationId: consultationId,
        transactionId: ref,
        amount: amount,
      );

      if (onPaymentDetected != null) {
        onPaymentDetected!(paymentData);
      }
      return true;
    } catch (e) {
      return false;
    }
  }
}
