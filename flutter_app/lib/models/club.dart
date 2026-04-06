class Club {
  final String id;
  final String name;
  final String address;
  final double? lat;
  final double? lon;
  final List<String> photos;
  final Map<String, String> workingHours; // {"mon": "10:00-02:00", ...}
  final int pcCount;
  final double rating;
  final String status;
  final String tier; // 'basic' | 'standard' | 'vip'
  final bool hasPlaystation;
  final String? description;
  final int pricePerHour;
  final int reviewCount;
  final String? contactPhone;
  final String? contactTelegram;
  double? distanceMeters;

  Club({
    required this.id,
    required this.name,
    required this.address,
    this.lat,
    this.lon,
    required this.photos,
    required this.workingHours,
    required this.pcCount,
    required this.rating,
    required this.status,
    required this.tier,
    this.hasPlaystation = false,
    this.description,
    this.pricePerHour = 12000,
    this.reviewCount = 0,
    this.contactPhone,
    this.contactTelegram,
    this.distanceMeters,
  });

  bool get isOpen {
    final now = DateTime.now();
    final dayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
    final current = now.hour * 60 + now.minute;

    // Check today's schedule
    if (_isOpenForDay(dayKeys[now.weekday - 1], current, false)) return true;

    // Check yesterday's schedule (for overnight hours, e.g., 22:00-04:00 — now is 1:00 AM)
    final yesterdayIdx = (now.weekday - 2) % 7;
    if (_isOpenForDay(dayKeys[yesterdayIdx], current, true)) return true;

    return false;
  }

  bool _isOpenForDay(String dayKey, int currentMinutes, bool checkOverflowOnly) {
    final hours = workingHours[dayKey];
    if (hours == null) return false;

    final parts = hours.split('-');
    if (parts.length != 2) return false;

    try {
      final open = _parseTime(parts[0]);
      final close = _parseTime(parts[1]);

      if (close < open) {
        // Overnight schedule
        if (checkOverflowOnly) {
          // Only check the after-midnight portion
          return currentMinutes <= close;
        }
        return currentMinutes >= open || currentMinutes <= close;
      }

      if (checkOverflowOnly) return false;
      return currentMinutes >= open && currentMinutes <= close;
    } catch (_) {
      return false;
    }
  }

  int _parseTime(String t) {
    final p = t.trim().split(':');
    return int.parse(p[0]) * 60 + int.parse(p[1]);
  }

  String get tierLabel => switch (tier) {
    'vip' => 'VIP',
    'standard' => 'Стандарт',
    _ => 'Базовый',
  };

  String? get thumbnail => photos.isNotEmpty ? photos.first : null;

  String get distanceText {
    if (distanceMeters == null) return '';
    if (distanceMeters! < 1000) return '${distanceMeters!.round()} м';
    return '${(distanceMeters! / 1000).toStringAsFixed(1)} км';
  }

  factory Club.fromJson(Map<String, dynamic> json) => Club(
    id: json['id'] as String,
    name: json['name'] as String,
    address: json['address'] as String,
    lat: (json['lat'] as num?)?.toDouble(),
    lon: (json['lon'] as num?)?.toDouble(),
    photos: List<String>.from(json['photos'] as List? ?? []),
    workingHours: Map<String, String>.from(json['working_hours'] as Map? ?? {}),
    pcCount: json['pc_count'] as int? ?? 0,
    rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
    status: json['status'] as String? ?? 'active',
    tier: json['tier'] as String? ?? 'basic',
    hasPlaystation: json['has_playstation'] as bool? ?? false,
    description: json['description'] as String?,
    pricePerHour: json['price_per_hour'] as int? ?? 12000,
    reviewCount: json['review_count'] as int? ?? 0,
    contactPhone: json['contact_phone'] as String?,
    contactTelegram: json['contact_telegram'] as String?,
  );
}
