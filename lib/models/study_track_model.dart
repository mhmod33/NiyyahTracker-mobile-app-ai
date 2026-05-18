enum StudySourceType { youtube, manual }

class StudyItem {
  final String id;
  final String title;
  final bool isWatched;
  final String? videoUrl;
  final String? notes;
  final int orderIndex;

  const StudyItem({
    required this.id,
    required this.title,
    this.isWatched = false,
    this.videoUrl,
    this.notes,
    required this.orderIndex,
  });

  bool get hasUrl => videoUrl != null && videoUrl!.isNotEmpty;

  String? get youtubeThumbnailUrl {
    if (videoUrl == null) return null;
    final vid = StudyPlaylist.extractYoutubeVideoId(videoUrl!);
    if (vid == null) return null;
    return 'https://img.youtube.com/vi/$vid/mqdefault.jpg';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'isWatched': isWatched,
        'videoUrl': videoUrl,
        'notes': notes,
        'orderIndex': orderIndex,
      };

  factory StudyItem.fromJson(Map<String, dynamic> json) => StudyItem(
        id: json['id'] as String,
        title: json['title'] as String,
        isWatched: json['isWatched'] as bool? ?? false,
        videoUrl: json['videoUrl'] as String?,
        notes: json['notes'] as String?,
        orderIndex: json['orderIndex'] as int? ?? 0,
      );

  StudyItem copyWith({
    String? title,
    bool? isWatched,
    String? videoUrl,
    String? notes,
    int? orderIndex,
  }) =>
      StudyItem(
        id: id,
        title: title ?? this.title,
        isWatched: isWatched ?? this.isWatched,
        videoUrl: videoUrl ?? this.videoUrl,
        notes: notes ?? this.notes,
        orderIndex: orderIndex ?? this.orderIndex,
      );
}

class StudyPlaylist {
  final String id;
  final String title;
  final String? description;
  final String? externalUrl;
  final StudySourceType type;
  final List<StudyItem> items;
  final DateTime createdAt;

  const StudyPlaylist({
    required this.id,
    required this.title,
    this.description,
    this.externalUrl,
    this.type = StudySourceType.manual,
    this.items = const [],
    required this.createdAt,
  });

  int get watchedCount => items.where((i) => i.isWatched).length;
  int get totalCount => items.length;
  double get progress =>
      totalCount == 0 ? 0.0 : (watchedCount / totalCount).clamp(0.0, 1.0);
  bool get isCompleted => totalCount > 0 && watchedCount >= totalCount;

  List<StudyItem> get sortedItems =>
      List<StudyItem>.from(items)..sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

  static String? extractYoutubePlaylistId(String url) {
    try {
      return Uri.parse(url).queryParameters['list'];
    } catch (_) {
      return null;
    }
  }

  static String? extractYoutubeVideoId(String url) {
    try {
      final uri = Uri.parse(url);
      if (uri.host.contains('youtu.be')) {
        return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
      }
      if (uri.host.contains('youtube.com')) {
        return uri.queryParameters['v'];
      }
    } catch (_) {}
    return null;
  }

  static bool isYoutubeUrl(String url) {
    try {
      final host = Uri.parse(url).host;
      return host.contains('youtube.com') || host.contains('youtu.be');
    } catch (_) {
      return false;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'externalUrl': externalUrl,
        'type': type.name,
        'items': items.map((i) => i.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };

  factory StudyPlaylist.fromJson(Map<String, dynamic> json) => StudyPlaylist(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        externalUrl: json['externalUrl'] as String?,
        type: StudySourceType.values.firstWhere(
          (e) => e.name == (json['type'] as String? ?? ''),
          orElse: () => StudySourceType.manual,
        ),
        items: (json['items'] as List? ?? [])
            .map((e) => StudyItem.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList(),
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      );

  StudyPlaylist copyWith({
    String? title,
    String? description,
    String? externalUrl,
    StudySourceType? type,
    List<StudyItem>? items,
  }) =>
      StudyPlaylist(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        externalUrl: externalUrl ?? this.externalUrl,
        type: type ?? this.type,
        items: items ?? this.items,
        createdAt: createdAt,
      );
}
