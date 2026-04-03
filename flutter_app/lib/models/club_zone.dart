/// Зона внутри клуба (basic / pro / vip)
class ClubZone {
  final String id;
  final String clubId;
  final String name;
  final String type; // 'basic' | 'pro' | 'vip'
  final String? description;
  final int capacity;
  final int priceDay;     // UZS за час, день (08–20)
  final int priceEvening; // UZS за час, вечер (20–00)
  final int priceNight;   // UZS за час, ночь (00–08)
  final bool isActive;

  const ClubZone({
    required this.id,
    required this.clubId,
    required this.name,
    required this.type,
    this.description,
    required this.capacity,
    required this.priceDay,
    required this.priceEvening,
    required this.priceNight,
    this.isActive = true,
  });

  String get typeLabel => switch (type) {
    'basic' => 'Базовая',
    'pro' => 'Про',
    'vip' => 'VIP',
    _ => type,
  };

  /// Цена в текущем тайм-слоте
  int priceForSlot(String slot) => switch (slot) {
    'day' => priceDay,
    'evening' => priceEvening,
    'night' => priceNight,
    _ => priceDay,
  };

  factory ClubZone.fromJson(Map<String, dynamic> json) => ClubZone(
    id: json['id'] as String,
    clubId: json['club_id'] as String,
    name: json['name'] as String,
    type: json['type'] as String? ?? 'basic',
    description: json['description'] as String?,
    capacity: json['capacity'] as int? ?? 0,
    priceDay: json['price_day'] as int? ?? 0,
    priceEvening: json['price_evening'] as int? ?? 0,
    priceNight: json['price_night'] as int? ?? 0,
    isActive: json['is_active'] as bool? ?? true,
  );
}
