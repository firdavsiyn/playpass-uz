class Tournament {
  final String id;
  final String clubId;
  final String? clubName;
  final String title;
  final String? description;
  final String game;
  final String? imageUrl;
  final int maxPlayers;
  final int entryFee;
  final String? prizePool;
  final String status;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String? rules;
  final int participantCount;
  final DateTime createdAt;

  const Tournament({
    required this.id,
    required this.clubId,
    this.clubName,
    required this.title,
    this.description,
    required this.game,
    this.imageUrl,
    required this.maxPlayers,
    required this.entryFee,
    this.prizePool,
    required this.status,
    required this.startsAt,
    this.endsAt,
    this.rules,
    this.participantCount = 0,
    required this.createdAt,
  });

  factory Tournament.fromJson(Map<String, dynamic> json) => Tournament(
    id: json['id'] as String,
    clubId: json['club_id'] as String,
    clubName: (json['clubs'] as Map<String, dynamic>?)?['name'] as String?,
    title: json['title'] as String,
    description: json['description'] as String?,
    game: json['game'] as String? ?? 'CS2',
    imageUrl: json['image_url'] as String?,
    maxPlayers: json['max_players'] as int? ?? 16,
    entryFee: json['entry_fee'] as int? ?? 0,
    prizePool: json['prize_pool'] as String?,
    status: json['status'] as String? ?? 'upcoming',
    startsAt: DateTime.parse(json['starts_at'] as String),
    endsAt: json['ends_at'] != null ? DateTime.parse(json['ends_at'] as String) : null,
    rules: json['rules'] as String?,
    participantCount: json['participant_count'] as int? ??
        (json['tournament_participants'] as List?)?.length ?? 0,
    createdAt: DateTime.parse(json['created_at'] as String),
  );

  bool get isRegistrationOpen => status == 'upcoming' || status == 'registration';
  bool get isFull => participantCount >= maxPlayers;
  bool get isFree => entryFee == 0;
}
