class Story {
  final String id;
  final String? clubId;
  final String? clubName;
  final String? clubLogo;
  final String authorType;
  final String title;
  final String? body;
  final String? imageUrl;
  final String? videoUrl;
  final String? linkUrl;
  final String? linkLabel;
  final bool isPinned;
  final int viewsCount;
  final bool isViewed;
  final DateTime createdAt;

  const Story({
    required this.id,
    this.clubId,
    this.clubName,
    this.clubLogo,
    required this.authorType,
    required this.title,
    this.body,
    this.imageUrl,
    this.videoUrl,
    this.linkUrl,
    this.linkLabel,
    this.isPinned = false,
    this.viewsCount = 0,
    this.isViewed = false,
    required this.createdAt,
  });

  factory Story.fromJson(Map<String, dynamic> json, {Set<String>? viewedIds}) {
    final id = json['id'] as String;
    return Story(
      id: id,
      clubId: json['club_id'] as String?,
      clubName: (json['clubs'] as Map<String, dynamic>?)?['name'] as String?,
      clubLogo: (json['clubs'] as Map<String, dynamic>?)?['logo_url'] as String?,
      authorType: json['author_type'] as String? ?? 'club',
      title: json['title'] as String,
      body: json['body'] as String?,
      imageUrl: json['image_url'] as String?,
      videoUrl: json['video_url'] as String?,
      linkUrl: json['link_url'] as String?,
      linkLabel: json['link_label'] as String?,
      isPinned: json['is_pinned'] as bool? ?? false,
      viewsCount: json['views_count'] as int? ?? 0,
      isViewed: viewedIds?.contains(id) ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}м';
    if (diff.inHours < 24) return '${diff.inHours}ч';
    if (diff.inDays < 7) return '${diff.inDays}д';
    return '${(diff.inDays / 7).floor()}н';
  }
}
