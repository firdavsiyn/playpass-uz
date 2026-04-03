/// Заявка на подписку (ручная оплата MVP)
class SubscriptionRequest {
  final String id;
  final String userId;
  final String plan;
  final int amountUzs;
  final String? userPhone;
  final String? paymentNote;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? rejectionReason;
  final DateTime createdAt;
  final DateTime? processedAt;

  const SubscriptionRequest({
    required this.id,
    required this.userId,
    required this.plan,
    required this.amountUzs,
    this.userPhone,
    this.paymentNote,
    required this.status,
    this.rejectionReason,
    required this.createdAt,
    this.processedAt,
  });

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';

  String get planName => switch (plan) {
    'basic' => 'Базовый',
    'standard' => 'Стандарт',
    'pro' => 'Про',
    'vip' => 'VIP',
    _ => plan,
  };

  factory SubscriptionRequest.fromJson(Map<String, dynamic> json) =>
      SubscriptionRequest(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        plan: json['plan'] as String,
        amountUzs: json['amount_uzs'] as int? ?? 0,
        userPhone: json['user_phone'] as String?,
        paymentNote: json['payment_note'] as String?,
        status: json['status'] as String? ?? 'pending',
        rejectionReason: json['rejection_reason'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
        processedAt: json['processed_at'] != null
            ? DateTime.parse(json['processed_at'] as String)
            : null,
      );
}
