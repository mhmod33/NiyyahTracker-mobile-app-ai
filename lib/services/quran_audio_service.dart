import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'audio_link_resolver.dart';
import 'shared_library_service.dart';

// ─── Snippet Track ───────────────────────────────────────────────────────────

class SnippetTrack {
  final String title;
  final String assetPath;

  /// Optional absolute file path (for user-uploaded tracks).
  /// When non-null this takes precedence over [assetPath].
  final String? filePath;

  /// Firebase Storage download URL (shared library — visible to all users).
  final String? remoteUrl;

  /// Firestore document id for shared tracks (delete / cache key).
  final String? cloudTrackId;

  /// Storage path in Firebase (for admin delete).
  final String? storagePath;

  /// Optional reciter id for tracks that the user uploaded under a custom
  /// reciter name. Used to group tracks by reciter at runtime.
  final String? reciterId;

  const SnippetTrack({
    required this.title,
    required this.assetPath,
    this.filePath,
    this.remoteUrl,
    this.cloudTrackId,
    this.storagePath,
    this.reciterId,
  });

  bool get isUserUploaded => filePath != null;
  bool get isShared => cloudTrackId != null && cloudTrackId!.isNotEmpty;

  Map<String, dynamic> toJson() => {
    'title': title,
    'assetPath': assetPath,
    'filePath': filePath,
    'remoteUrl': remoteUrl,
    'cloudTrackId': cloudTrackId,
    'storagePath': storagePath,
    'reciterId': reciterId,
  };

  factory SnippetTrack.fromJson(Map<String, dynamic> json) => SnippetTrack(
    title: json['title'] as String,
    assetPath: (json['assetPath'] as String?) ?? '',
    filePath: json['filePath'] as String?,
    remoteUrl: json['remoteUrl'] as String?,
    cloudTrackId: json['cloudTrackId'] as String?,
    storagePath: json['storagePath'] as String?,
    reciterId: json['reciterId'] as String?,
  );
}

// ─── Reciter Model ───────────────────────────────────────────────────────────

enum ReciterType { snippets, full }

class Reciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String description;
  final ReciterType type;

  /// For [ReciterType.full]: CDN identifier used in URL (alquran.cloud)
  final String? cdnId;

  /// For [ReciterType.full]: mp3quran.net server base URL (fallback for streaming)
  /// Format: 'https://server12.mp3quran.net/maher/' — surah appended as '001.mp3'
  final String? mp3QuranServer;

  /// For [ReciterType.snippets]: list of tracks
  final List<SnippetTrack>? snippetTracks;

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.type,
    this.cdnId,
    this.mp3QuranServer,
    this.snippetTracks,
  });
}

// ─── Playback State ──────────────────────────────────────────────────────────

class QuranPlaybackState {
  final bool isPlaying;
  final bool isLoading;
  final int? currentSurah;
  final String? currentReciterId;
  final Duration position;
  final Duration duration;

  const QuranPlaybackState({
    this.isPlaying = false,
    this.isLoading = false,
    this.currentSurah,
    this.currentReciterId,
    this.position = Duration.zero,
    this.duration = Duration.zero,
  });

  QuranPlaybackState copyWith({
    bool? isPlaying,
    bool? isLoading,
    int? currentSurah,
    String? currentReciterId,
    Duration? position,
    Duration? duration,
  }) {
    return QuranPlaybackState(
      isPlaying: isPlaying ?? this.isPlaying,
      isLoading: isLoading ?? this.isLoading,
      currentSurah: currentSurah ?? this.currentSurah,
      currentReciterId: currentReciterId ?? this.currentReciterId,
      position: position ?? this.position,
      duration: duration ?? this.duration,
    );
  }
}

// ─── Service ─────────────────────────────────────────────────────────────────

class QuranAudioService extends ChangeNotifier {
  static final QuranAudioService _instance = QuranAudioService._internal();
  factory QuranAudioService() => _instance;
  QuranAudioService._internal();

  late AudioPlayer _player;
  late Box _settingsBox;
  bool _initialized = false;

  QuranPlaybackState _state = const QuranPlaybackState();
  QuranPlaybackState get state => _state;

  StreamSubscription? _playerStateSub;
  StreamSubscription? _positionSub;
  StreamSubscription? _durationSub;

  // ── Available Reciters ────────────────────────────────────────────────────

  /// Built-in reciters bundled with the app.
  ///
  /// Snippets (مقتطفات) are no longer bundled — they live in the shared library
  /// as admin-added streaming links (see [SharedLibraryService.addLinkSnippet]).
  static const List<Reciter> _builtInReciters = [
    // ── Full Reciters (download on demand) ──
    Reciter(
      id: 'alafasy',
      nameAr: 'مشاري العفاسي',
      nameEn: 'Mishary Alafasy',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ مشاري العفاسي',
      type: ReciterType.full,
      cdnId: 'ar.alafasy',
      mp3QuranServer: 'https://server8.mp3quran.net/afs/',
    ),
    Reciter(
      id: 'maher',
      nameAr: 'ماهر المعيقلي',
      nameEn: 'Maher Al Muaiqly',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ ماهر المعيقلي',
      type: ReciterType.full,
      cdnId: 'ar.mahermuaiqly',
      mp3QuranServer: 'https://server12.mp3quran.net/maher/',
    ),
    Reciter(
      id: 'husary',
      nameAr: 'محمود خليل الحصري',
      nameEn: 'Mahmoud Khalil Al-Husary',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ محمود خليل الحصري',
      type: ReciterType.full,
      cdnId: 'ar.husary',
      mp3QuranServer: 'https://server13.mp3quran.net/husr/',
    ),
    Reciter(
      id: 'minshawi',
      nameAr: 'محمد صديق المنشاوي',
      nameEn: 'Muhammad Siddiq Al-Minshawi',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ محمد صديق المنشاوي',
      type: ReciterType.full,
      cdnId: 'ar.minshawi',
      mp3QuranServer: 'https://server10.mp3quran.net/minsh/',
    ),
  ];

  /// Admin-added shared snippets from Firestore (streaming links) — visible to all users.
  static List<Reciter> _sharedReciters = const [];

  /// All reciters: built-in full reciters + shared cloud snippets.
  static List<Reciter> get reciters {
    return [..._builtInReciters, ..._sharedReciters];
  }

  // ── Settings Keys ─────────────────────────────────────────────────────────

  static const String _selectedReciterKey = 'quran_selected_reciter';
  static const String _lastSurahKey = 'quran_last_surah';

  // ── Init ──────────────────────────────────────────────────────────────────

  Future<void> init() async {
    if (_initialized) return;
    developer.log('🎵 QuranAudioService.init()', name: 'QuranAudio');

    _player = AudioPlayer();

    // Configure audio session — share focus with AzanService
    try {
      final session = await AudioSession.instance;
      await session.configure(
        const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: true,
        ),
      );
      session.interruptionEventStream.listen((event) {
        if (event.begin) _player.pause();
      });
      session.becomingNoisyEventStream.listen((_) => _player.pause());
    } catch (e) {
      developer.log('⚠️ Audio session error: $e', name: 'QuranAudio');
    }

    // Open settings box
    if (!Hive.isBoxOpen('quran_audio_settings')) {
      _settingsBox = await Hive.openBox('quran_audio_settings');
    } else {
      _settingsBox = Hive.box('quran_audio_settings');
    }

    // Load cloud shared library (admin-added streaming links).
    await refreshSharedLibrary();

    // Subscribe to player streams
    _playerStateSub = _player.playerStateStream.listen((ps) {
      _state = _state.copyWith(
        isPlaying: ps.playing,
        isLoading:
            ps.processingState == ProcessingState.loading ||
            ps.processingState == ProcessingState.buffering,
      );
      if (ps.processingState == ProcessingState.completed) {
        _onSurahCompleted();
      }
      notifyListeners();
    });

    _positionSub = _player.positionStream.listen((pos) {
      _state = _state.copyWith(position: pos);
      notifyListeners();
    });

    _durationSub = _player.durationStream.listen((dur) {
      if (dur != null) {
        _state = _state.copyWith(duration: dur);
        notifyListeners();
      }
    });

    _initialized = true;
    developer.log('✅ QuranAudioService initialized', name: 'QuranAudio');
  }

  // ── Getters ───────────────────────────────────────────────────────────────

  String get selectedReciterId {
    final stored = _settingsBox.get(
      _selectedReciterKey,
      defaultValue: _builtInReciters.first.id,
    ) as String;
    return reciters.any((r) => r.id == stored)
        ? stored
        : _builtInReciters.first.id;
  }

  Reciter get selectedReciter => reciters.firstWhere(
    (r) => r.id == selectedReciterId,
    orElse: () => reciters.first,
  );

  int get lastSurah => _settingsBox.get(_lastSurahKey, defaultValue: 1);

  bool get isPlaying => _state.isPlaying;
  bool get hasActiveSurah => _state.currentSurah != null;

  /// Direct streams from the player for real-time UI updates
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;

  // ── Setters ───────────────────────────────────────────────────────────────

  Future<void> setSelectedReciter(String id) async {
    await _settingsBox.put(_selectedReciterKey, id);
    notifyListeners();
  }

  // ── Playback ──────────────────────────────────────────────────────────────

  /// Play a surah with the given reciter (or currently selected one).
  /// For snippet reciters, [surahNumber] is used as track index (0-based).
  Future<void> playSurah(int surahNumber, {String? reciterId}) async {
    if (!_initialized) await init();

    final rid = reciterId ?? selectedReciterId;
    final reciter = reciters.firstWhere(
      (r) => r.id == rid,
      orElse: () => selectedReciter,
    );

    developer.log(
      '▶️ playSurah($surahNumber) reciter=${reciter.id}',
      name: 'QuranAudio',
    );

    _state = _state.copyWith(
      isLoading: true,
      currentSurah: surahNumber,
      currentReciterId: reciter.id,
    );
    notifyListeners();

    try {
      if (reciter.type == ReciterType.snippets) {
        await _playSnippet(surahNumber, reciter);
      } else {
        await _playFullSurah(surahNumber, reciter);
      }
      await _settingsBox.put(_lastSurahKey, surahNumber);
    } catch (e, st) {
      developer.log(
        '❌ playSurah error',
        name: 'QuranAudio',
        error: e,
        stackTrace: st,
      );
      _state = _state.copyWith(isLoading: false, isPlaying: false);
      notifyListeners();
    }
  }

  /// Play a snippet track by index.
  Future<void> playSnippetTrack(int trackIndex, {String? reciterId}) async {
    final targetReciterId = reciterId ??
        reciters
            .firstWhere(
              (r) => r.type == ReciterType.snippets,
              orElse: () => selectedReciter,
            )
            .id;
    await playSurah(trackIndex, reciterId: targetReciterId);
  }

  Future<void> _playSnippet(int trackIndex, Reciter reciter) async {
    final tracks = reciter.snippetTracks;
    if (tracks == null || tracks.isEmpty) {
      developer.log(
        '⚠️ No snippet tracks for reciter ${reciter.id}',
        name: 'QuranAudio',
      );
      _state = _state.copyWith(isLoading: false, currentSurah: null);
      notifyListeners();
      return;
    }
    final safeIndex = trackIndex.clamp(0, tracks.length - 1);
    final track = tracks[safeIndex];
    if (track.remoteUrl != null && track.remoteUrl!.isNotEmpty) {
      // Streaming link (admin-added shared snippet). Resolve page links
      // (e.g. SoundCloud) to a direct stream URL just before playing.
      final playable = await AudioLinkResolver.resolve(track.remoteUrl!);
      developer.log('🌐 Streaming snippet: $playable', name: 'QuranAudio');
      await _player.setUrl(playable);
    } else if (track.isShared) {
      // Legacy shared track stored as Firestore chunks — download then play.
      final local = await _resolveSharedTrackLocalPath(track);
      developer.log('▶️ Playing shared snippet: $local', name: 'QuranAudio');
      if (local == null) {
        _state = _state.copyWith(isLoading: false);
        notifyListeners();
        throw Exception('تعذر تحميل المقطع من السحابة');
      }
      await _player.setFilePath(local);
    } else {
      _state = _state.copyWith(isLoading: false);
      notifyListeners();
      throw Exception('لا يوجد مصدر صوتي لهذا المقطع');
    }
    await _player.play();
  }

  Future<void> _playFullSurah(int surahNumber, Reciter reciter) async {
    final localPath = await _getLocalPath(reciter.id, surahNumber);
    final localFile = File(localPath);

    if (await localFile.exists()) {
      developer.log('📂 Playing from local: $localPath', name: 'QuranAudio');
      await _player.setFilePath(localPath);
    } else {
      // Prefer mp3quran.net server (more reliable for streaming)
      // Fall back to cdn.islamic.network if no server defined
      final url = _buildStreamUrl(reciter, surahNumber);
      developer.log('🌐 Streaming: $url', name: 'QuranAudio');
      await _player.setUrl(url);
    }
    await _player.play();
  }

  Future<void> pause() async {
    await _player.pause();
  }

  Future<void> resume() async {
    await _player.play();
  }

  Future<void> stop() async {
    await _player.stop();
    _state = const QuranPlaybackState();
    notifyListeners();
  }

  Future<void> seekTo(Duration position) async {
    await _player.seek(position);
  }

  Future<void> playNext() async {
    final current = _state.currentSurah;
    if (current == null) return;
    final reciter = reciters.firstWhere(
      (r) => r.id == (_state.currentReciterId ?? selectedReciterId),
      orElse: () => selectedReciter,
    );
    if (reciter.type == ReciterType.snippets) {
      final total = reciter.snippetTracks?.length ?? 0;
      final next = (current + 1) % total;
      await playSurah(next, reciterId: reciter.id);
    } else {
      final next = current < 114 ? current + 1 : 1;
      await playSurah(next, reciterId: reciter.id);
    }
  }

  Future<void> playPrevious() async {
    final current = _state.currentSurah;
    if (current == null) return;
    final reciter = reciters.firstWhere(
      (r) => r.id == (_state.currentReciterId ?? selectedReciterId),
      orElse: () => selectedReciter,
    );
    if (reciter.type == ReciterType.snippets) {
      final total = reciter.snippetTracks?.length ?? 1;
      final prev = current > 0 ? current - 1 : total - 1;
      await playSurah(prev, reciterId: reciter.id);
    } else {
      final prev = current > 1 ? current - 1 : 114;
      await playSurah(prev, reciterId: reciter.id);
    }
  }

  void _onSurahCompleted() {
    developer.log('✅ Track completed, auto-advancing', name: 'QuranAudio');
    playNext();
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  /// Build streaming URL — prefers mp3quran.net server, falls back to cdn.islamic.network.
  /// mp3quran.net format: {server}{surah_padded_3}.mp3  e.g. 001.mp3
  /// cdn.islamic.network format: audio-surah/128/{cdnId}/{surah}.mp3
  String _buildStreamUrl(Reciter reciter, int surahNumber) {
    if (reciter.mp3QuranServer != null) {
      final padded = surahNumber.toString().padLeft(3, '0');
      return '${reciter.mp3QuranServer}$padded.mp3';
    }
    // Fallback to alquran.cloud CDN
    return _buildCdnUrl(reciter.cdnId!, surahNumber);
  }

  String _buildCdnUrl(String cdnId, int surahNumber) {
    return 'https://cdn.islamic.network/quran/audio-surah/128/$cdnId/$surahNumber.mp3';
  }

  Future<String> _getLocalPath(String reciterId, int surahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final paddedNum = surahNumber.toString().padLeft(3, '0');
    return '${dir.path}/quran_audio/$reciterId/$paddedNum.mp3';
  }

  /// Check if a surah is downloaded for a given reciter.
  Future<bool> isSurahDownloaded(String reciterId, int surahNumber) async {
    final path = await _getLocalPath(reciterId, surahNumber);
    return File(path).exists();
  }

  /// Check how many surahs are downloaded for a reciter (0–114).
  Future<int> downloadedSurahCount(String reciterId) async {
    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (await isSurahDownloaded(reciterId, i)) count++;
    }
    return count;
  }

  /// Returns true if the reciter is fully available offline.
  Future<bool> isReciterFullyDownloaded(String reciterId) async {
    final reciter = reciters.firstWhere(
      (r) => r.id == reciterId,
      orElse: () => reciters.first,
    );
    if (reciter.type == ReciterType.snippets) return true;
    return (await downloadedSurahCount(reciterId)) == 114;
  }

  /// Delete all downloaded files for a reciter.
  Future<void> deleteReciter(String reciterId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio/$reciterId');
    if (await folder.exists()) {
      await folder.delete(recursive: true);
      developer.log('🗑️ Deleted reciter: $reciterId', name: 'QuranAudio');
    }
    notifyListeners();
  }

  // ── Custom (user-uploaded) snippet reciters ──────────────────────────────

  static List<SnippetTrack> _mergeSnippetTracks(
    List<SnippetTrack> current,
    List<SnippetTrack> incoming,
  ) {
    final merged = <SnippetTrack>[];
    final keys = <String>{};

    void addTrack(SnippetTrack track) {
      final key = track.cloudTrackId?.isNotEmpty == true
          ? 'id:${track.cloudTrackId}'
          : 'url:${track.remoteUrl}|title:${track.title}';
      if (keys.add(key)) merged.add(track);
    }

    for (final track in incoming) {
      addTrack(track);
    }
    for (final track in current) {
      addTrack(track);
    }

    return merged;
  }

  static List<Reciter> _mergeSharedReciters(
    List<Reciter> current,
    List<Reciter> incoming,
  ) {
    final byId = <String, Reciter>{for (final r in incoming) r.id: r};

    for (final existing in current) {
      final fetched = byId[existing.id];
      if (fetched == null) {
        byId[existing.id] = existing;
        continue;
      }

      byId[existing.id] = Reciter(
        id: fetched.id,
        nameAr: fetched.nameAr,
        nameEn: fetched.nameEn,
        description: fetched.description,
        type: fetched.type,
        snippetTracks: _mergeSnippetTracks(
          existing.snippetTracks ?? const [],
          fetched.snippetTracks ?? const [],
        ),
      );
    }

    return byId.values.toList();
  }

  /// Reload shared snippets from Firestore (call when opening library page).
  Future<void> refreshSharedLibrary({
    bool preserveExisting = true,
    bool allowEmpty = false,
  }) async {
    final fetched = await SharedLibraryService().fetchSharedReciters();
    if (fetched.isEmpty && _sharedReciters.isNotEmpty && !allowEmpty) {
      return;
    }
    _sharedReciters = preserveExisting
        ? _mergeSharedReciters(_sharedReciters, fetched)
        : fetched;
    notifyListeners();
  }

  Future<String?> _resolveSharedTrackLocalPath(SnippetTrack track) async {
    if (track.cloudTrackId == null) return null;
    return SharedLibraryService().ensureTrackCached(track.cloudTrackId!);
  }

  /// Add a snippet that streams from a direct audio URL (admin only).
  /// Saves a lightweight metadata doc to the shared library so the track
  /// appears for all users, then refreshes the in-memory list.
  Future<void> addSharedLink({
    required String reciterName,
    required String trackTitle,
    required String remoteUrl,
    String? uploadedByUid,
    String? uploadedByName,
  }) async {
    if (!_initialized) await init();

    final trackId = await SharedLibraryService().addLinkSnippet(
      reciterName: reciterName,
      trackTitle: trackTitle,
      remoteUrl: remoteUrl,
      uploadedByUid: uploadedByUid ?? '',
      uploadedByName: uploadedByName ?? 'الإدارة',
    );

    final reciterId = SharedLibraryService.reciterIdFor(reciterName);
    final track = SnippetTrack(
      title: trackTitle.trim(),
      assetPath: '',
      remoteUrl: remoteUrl.trim(),
      reciterId: reciterId,
      cloudTrackId: trackId,
    );
    final existingIndex = _sharedReciters.indexWhere((r) => r.id == reciterId);
    if (existingIndex >= 0) {
      final existing = _sharedReciters[existingIndex];
      final tracks = [...?existing.snippetTracks, track];
      _sharedReciters = [
        ..._sharedReciters.take(existingIndex),
        Reciter(
          id: existing.id,
          nameAr: existing.nameAr,
          nameEn: existing.nameEn,
          description: existing.description,
          type: existing.type,
          snippetTracks: tracks,
        ),
        ..._sharedReciters.skip(existingIndex + 1),
      ];
    } else {
      _sharedReciters = [
        ..._sharedReciters,
        Reciter(
          id: reciterId,
          nameAr: reciterName.trim(),
          nameEn: '',
          description: 'مقتطفات مشتركة — متاحة للجميع',
          type: ReciterType.snippets,
          snippetTracks: [track],
        ),
      ];
    }
    notifyListeners();

    try {
      await refreshSharedLibrary().timeout(const Duration(seconds: 20));
    } catch (_) {
      // Save succeeded; list refresh can fail without blocking.
    }
  }

  /// Remove a shared (cloud) track — admin only, enforced by rules.
  Future<void> removeSharedSnippet(String reciterId, int trackIndex) async {
    final idx = _sharedReciters.indexWhere((r) => r.id == reciterId);
    if (idx < 0) return;
    final reciter = _sharedReciters[idx];
    final tracks = [...?reciter.snippetTracks];
    if (trackIndex < 0 || trackIndex >= tracks.length) return;
    final removed = tracks[trackIndex];
    if (removed.cloudTrackId != null) {
      await SharedLibraryService().deleteSharedTrack(
        removed.cloudTrackId!,
        removed.storagePath,
      );
    }
    await refreshSharedLibrary(preserveExisting: false, allowEmpty: true);
  }

  /// Remove a single shared snippet track — admin only, enforced by rules.
  /// (Kept under this name so existing call sites stay unchanged.)
  Future<void> removeUserSnippet(String reciterId, int trackIndex) async {
    await removeSharedSnippet(reciterId, trackIndex);
  }

  /// Remove an entire shared reciter and all of its tracks — admin only.
  Future<void> removeSharedReciter(String reciterId) async {
    final idx = _sharedReciters.indexWhere((r) => r.id == reciterId);
    if (idx < 0) return;
    final reciter = _sharedReciters[idx];
    for (final t in reciter.snippetTracks ?? const []) {
      if (t.cloudTrackId != null) {
        await SharedLibraryService()
            .deleteSharedTrack(t.cloudTrackId!, t.storagePath);
      }
    }
    await refreshSharedLibrary(preserveExisting: false, allowEmpty: true);
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
