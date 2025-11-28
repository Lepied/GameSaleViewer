/// Supabase에 저장되는 찜 목록 모델
class Favorite {
  final int? id;
  final String userId;
  final String gameId;
  final String gameTitle;
  final String thumbUrl;
  final DateTime createdAt;

  Favorite({
    this.id,
    required this.userId,
    required this.gameId,
    required this.gameTitle,
    required this.thumbUrl,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  /// Supabase JSON에서 객체로 변환
  factory Favorite.fromJson(Map<String, dynamic> json) {
    return Favorite(
      id: json['id'] as int?,
      userId: json['user_id'] ?? '',
      gameId: json['game_id'] ?? '',
      gameTitle: json['game_title'] ?? '',
      thumbUrl: json['thumb_url'] ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
    );
  }

  /// 객체를 Supabase JSON으로 변환
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_id': userId,
      'game_id': gameId,
      'game_title': gameTitle,
      'thumb_url': thumbUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// 찜 목록 추가를 위한 JSON (id 제외)
  Map<String, dynamic> toInsertJson() {
    return {
      'user_id': userId,
      'game_id': gameId,
      'game_title': gameTitle,
      'thumb_url': thumbUrl,
    };
  }
}
