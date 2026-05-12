import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

// ─── Snippet Track ───────────────────────────────────────────────────────────

class SnippetTrack {
  final String title;
  final String assetPath;

  const SnippetTrack({required this.title, required this.assetPath});
}

// ─── Reciter Model ───────────────────────────────────────────────────────────

enum ReciterType { snippets, full }

class Reciter {
  final String id;
  final String nameAr;
  final String nameEn;
  final String description;
  final ReciterType type;

  /// For [ReciterType.full]: CDN identifier used in URL
  final String? cdnId;

  /// For [ReciterType.snippets]: list of tracks
  final List<SnippetTrack>? snippetTracks;

  const Reciter({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.type,
    this.cdnId,
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

  static const List<Reciter> reciters = [
    // ── Snippets (bundled in assets — available immediately) ──
    Reciter(
      id: 'snippets_ahmed_fouad',
      nameAr: 'أحمد فؤاد — مقتطفات',
      nameEn: 'Ahmed Fouad — Snippets',
      description: 'مقتطفات مختارة من تلاوات الشيخ أحمد فؤاد',
      type: ReciterType.snippets,
      snippetTracks: [
        SnippetTrack(title: 'سورة الرحمن', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/_سورة الرحمن الشيخ أحمد فؤاد بني سويف(128K).mp3'),
        SnippetTrack(title: 'آيات من سورة يوسف', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/آيات_من_سورة_يوسف(128K).mp3'),
        SnippetTrack(title: 'آيات من العنكبوت', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/أيات من العنكبوت ليلة 21(128K).mp3'),
        SnippetTrack(title: 'آخر سورة الزمر', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/اخر_سورة_الزمر_الشيخ_احمد_فؤاد(128K).mp3'),
        SnippetTrack(title: 'آخر سورة الشعراء', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/اخر_سورة_الشعراء_الشيخ_احمد_فؤاد(128K).mp3'),
        SnippetTrack(title: 'الأعراف', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/الأعراف ، أحمد فؤاد(128K).mp3'),
        SnippetTrack(title: 'سورة هود', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/الشيخ أحمد فؤاد سورة هود.mp3'),
        SnippetTrack(title: 'سورة الطور والنجم', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/سورة_الطور_والنجم_للشيخ_احمد_فؤاد(128K).mp3'),
        SnippetTrack(title: 'سورة المطففين', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/سورة_المطففين_ودعاء_للشيخ_أحمد_فؤاد_(1).mp3'),
        SnippetTrack(title: 'آل عمران من الآية 149', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/سورة-آل-عمران-من-الآيه-149(128K).mp3'),
        SnippetTrack(title: 'سورة مريم', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/مريم_.._أحمد_فؤاد(128K).mp3'),
        SnippetTrack(title: 'من سورة الرعد', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/من_سورة_الرعد__،_القارئ_أحمد_فؤاد(128K).mp3'),
        SnippetTrack(title: 'نصف سورة الأحزاب', assetPath: 'assets/audio/quran/snippets/احمد فؤاد/نصف سورة  الأحزاب الثانى(128K).mp3'),
      ],
    ),
    // ── Full Reciters (download on demand) ──
    Reciter(
      id: 'alafasy',
      nameAr: 'مشاري العفاسي',
      nameEn: 'Mishary Alafasy',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ مشاري العفاسي',
      type: ReciterType.full,
      cdnId: 'ar.alafasy',
    ),
    Reciter(
      id: 'maher',
      nameAr: 'ماهر المعيقلي',
      nameEn: 'Maher Al Muaiqly',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ ماهر المعيقلي',
      type: ReciterType.full,
      cdnId: 'ar.mahermuaiqly',
    ),
    Reciter(
      id: 'husary',
      nameAr: 'محمود خليل الحصري',
      nameEn: 'Mahmoud Khalil Al-Husary',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ محمود خليل الحصري',
      type: ReciterType.full,
      cdnId: 'ar.husary',
    ),
    Reciter(
      id: 'minshawi',
      nameAr: 'محمد صديق المنشاوي',
      nameEn: 'Muhammad Siddiq Al-Minshawi',
      description: 'تلاوة كاملة للقرآن الكريم بصوت الشيخ محمد صديق المنشاوي',
      type: ReciterType.full,
      cdnId: 'ar.minshawi',
    ),
  ];

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
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.music,
          usage: AndroidAudioUsage.media,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
        androidWillPauseWhenDucked: true,
      ));
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

    // Subscribe to player streams
    _playerStateSub = _player.playerStateStream.listen((ps) {
      _state = _state.copyWith(
        isPlaying: ps.playing,
        isLoading: ps.processingState == ProcessingState.loading ||
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

  String get selectedReciterId =>
      _settingsBox.get(_selectedReciterKey, defaultValue: 'snippets_mishary');

  Reciter get selectedReciter =>
      reciters.firstWhere((r) => r.id == selectedReciterId,
          orElse: () => reciters.first);

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
    final reciter = reciters.firstWhere((r) => r.id == rid,
        orElse: () => selectedReciter);

    developer.log('▶️ playSurah($surahNumber) reciter=${reciter.id}', name: 'QuranAudio');

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
      developer.log('❌ playSurah error', name: 'QuranAudio', error: e, stackTrace: st);
      _state = _state.copyWith(isLoading: false, isPlaying: false);
      notifyListeners();
    }
  }

  /// Play a snippet track by index.
  Future<void> playSnippetTrack(int trackIndex, {String? reciterId}) async {
    await playSurah(trackIndex, reciterId: reciterId ?? 'snippets_ahmed_fouad');
  }

  Future<void> _playSnippet(int trackIndex, Reciter reciter) async {
    final tracks = reciter.snippetTracks;
    if (tracks == null || tracks.isEmpty) {
      developer.log('⚠️ No snippet tracks for reciter ${reciter.id}', name: 'QuranAudio');
      _state = _state.copyWith(isLoading: false, currentSurah: null);
      notifyListeners();
      return;
    }
    final safeIndex = trackIndex.clamp(0, tracks.length - 1);
    final track = tracks[safeIndex];
    developer.log('▶️ Playing snippet: ${track.assetPath}', name: 'QuranAudio');
    await _player.setAsset(track.assetPath);
    await _player.play();
  }

  Future<void> _playFullSurah(int surahNumber, Reciter reciter) async {
    final localPath = await _getLocalPath(reciter.id, surahNumber);
    final localFile = File(localPath);

    if (await localFile.exists()) {
      developer.log('📂 Playing from local: $localPath', name: 'QuranAudio');
      await _player.setFilePath(localPath);
    } else {
      final url = _buildCdnUrl(reciter.cdnId!, surahNumber);
      developer.log('🌐 Streaming from CDN: $url', name: 'QuranAudio');
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
    final reciter = reciters.firstWhere((r) => r.id == reciterId,
        orElse: () => reciters.first);
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

  @override
  void dispose() {
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    _durationSub?.cancel();
    _player.dispose();
    super.dispose();
  }
}
