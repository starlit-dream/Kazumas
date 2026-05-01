/// 单集进度
class BangumiEpisodeProgress {
  final int episodeId;
  final int type;

  const BangumiEpisodeProgress({
    required this.episodeId,
    required this.type,
  });

  factory BangumiEpisodeProgress.fromJson(Map<String, dynamic> json) {
    int id = 0;
    if (json['episode_id'] is int) {
      id = json['episode_id'];
    } else if (json['episode'] is Map<String, dynamic>) {
      id = json['episode']['id'] ?? 0;
    }
    return BangumiEpisodeProgress(
      episodeId: id,
      type: json['type'] ?? 0,
    );
  }

  bool get isWatched => type == 2;
}

/// 剧集进度响应
class BangumiEpisodeProgressResponse {
  final int total;
  final List<BangumiEpisodeProgress> data;

  const BangumiEpisodeProgressResponse({
    required this.total,
    required this.data,
  });

  factory BangumiEpisodeProgressResponse.fromJson(Map<String, dynamic> json) {
    final list = (json['data'] as List<dynamic>? ?? []);
    return BangumiEpisodeProgressResponse(
      total: json['total'] ?? list.length,
      data: list
          .whereType<Map<String, dynamic>>()
          .map(BangumiEpisodeProgress.fromJson)
          .toList(),
    );
  }

  int get watchedCount => data.where((e) => e.isWatched).length;
}
