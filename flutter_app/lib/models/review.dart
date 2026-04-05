/// Отзыв о клубе
class Review {
  final String id;
  final String clubId;
  final String userId;
  final String? userName;
  final int rating; // 1–5
  final String? text;
  final List<String> photoUrls;
  final DateTime createdAt;

  const Review({
    required this.id,
    required this.clubId,
    required this.userId,
    this.userName,
    required this.rating,
    this.text,
    this.photoUrls = const [],
    required this.createdAt,
  });

  factory Review.fromJson(Map<String, dynamic> json) => Review(
    id: json['id'] as String,
    clubId: json['club_id'] as String,
    userId: json['user_id'] as String,
    userName: (json['users'] as Map<String, dynamic>?)?['name'] as String?,
    rating: json['rating'] as int? ?? 5,
    text: json['comment'] as String?,
    photoUrls: (json['photo_urls'] as List<dynamic>?)?.cast<String>() ?? [],
    createdAt: DateTime.parse(json['created_at'] as String),
  );
}
