class Visit {
  final String id;
  final String userId;
  final String clubId;
  final String clubName;
  final int hoursSpent;
  final DateTime createdAt;

  const Visit({
    required this.id,
    required this.userId,
    required this.clubId,
    required this.clubName,
    required this.hoursSpent,
    required this.createdAt,
  });

  factory Visit.fromJson(Map<String, dynamic> json) => Visit(
        id: json['id'] as String,
        userId: json['user_id'] as String,
        clubId: json['club_id'] as String,
        clubName:
            (json['clubs'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        hoursSpent: json['hours_spent'] as int? ?? 1,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
