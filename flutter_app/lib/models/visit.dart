class Visit {
  final String id;
  final String userId;
  final String clubId;
  final String clubName;
  final String? zoneId;
  final String zoneType; // 'basic' | 'pro' | 'vip'
  final String timeSlot; // 'day' | 'evening' | 'night'
  final int hoursDeducted;
  final int priceAtCheckin;
  final DateTime createdAt;

  const Visit({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.clubName,
    this.zoneId,
    required this.zoneType,
    required this.timeSlot,
    required this.hoursDeducted,
    required this.priceAtCheckin,
    required this.createdAt,
  });

  String get zoneLabel => switch (zoneType) {
    'basic' => 'Базовая',
    'pro' => 'Про',
    'vip' => 'VIP',
    _ => zoneType,
  };

  String get timeSlotLabel => switch (timeSlot) {
    'day' => 'День',
    'evening' => 'Вечер',
    'night' => 'Ночь',
    _ => timeSlot,
  };

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
    id: json['id'] as String,
    userId: json['user_id'] as String,
    clubId: json['club_id'] as String,
    clubName: (json['clubs'] as Map<String, dynamic>?)?['name'] as String? ?? '',
    zoneId: json['zone_id'] as String?,
    zoneType: json['zone_type'] as String? ?? 'basic',
    timeSlot: json['time_slot'] as String? ?? 'day',
    hoursDeducted: json['hours_spent'] as int? ?? 1,
    priceAtCheckin: json['price_at_checkin'] as int? ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
