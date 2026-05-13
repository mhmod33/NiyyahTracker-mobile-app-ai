import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'quran_audio_service.dart';

// ─── Download State ───────────────────────────────────────────────────────────

class ReciterDownloadState {
  final bool isDownloading;
  final int downloadedCount;   // 0–114
  final int totalCount;        // always 114
  final int? currentSurah;     // surah being downloaded right now
  final String? error;
  final bool isCancelled;

  const ReciterDownloadState({
    this.isDownloading = false,
    this.downloadedCount = 0,
    this.totalCount = 114,
    this.currentSurah,
    this.error,
    this.isCancelled = false,
  });

  double get progress =>
      totalCount == 0 ? 0 : downloadedCount / totalCount;

  bool get isComplete => downloadedCount >= totalCount;

  ReciterDownloadState copyWith({
    bool? isDownloading,
    int? downloadedCount,
    int? totalCount,
    int? currentSurah,
    String? error,
    bool? isCancelled,
  }) {
    return ReciterDownloadState(
      isDownloading: isDownloading ?? this.isDownloading,
      downloadedCount: downloadedCount ?? this.downloadedCount,
      totalCount: totalCount ?? this.totalCount,
      currentSurah: currentSurah ?? this.currentSurah,
      error: error ?? this.error,
      isCancelled: isCancelled ?? this.isCancelled,
    );
  }
}

// ─── Service ──────────────────────────────────────────────────────────────────

class ReciterDownloadService extends ChangeNotifier {
  static final ReciterDownloadService _instance =
      ReciterDownloadService._internal();
  factory ReciterDownloadService() => _instance;
  ReciterDownloadService._internal();

  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 30),
    receiveTimeout: const Duration(minutes: 5),
  ));

  final Map<String, ReciterDownloadState> _states = {};
  final Map<String, CancelToken> _cancelTokens = {};

  ReciterDownloadState stateFor(String reciterId) =>
      _states[reciterId] ?? const ReciterDownloadState();

  // ── Approximate sizes (MB) per reciter ───────────────────────────────────

  static const Map<String, double> estimatedSizeMb = {
    'alafasy': 650,
    'maher': 700,
    'husary': 600,
    'minshawi': 580,
  };

  // ── Download ──────────────────────────────────────────────────────────────

  /// Start downloading all 114 surahs for a reciter.
  /// Resumes from where it left off if partially downloaded.
  Future<void> downloadReciter(String reciterId) async {
    final reciter = QuranAudioService.reciters
        .firstWhere((r) => r.id == reciterId, orElse: () => QuranAudioService.reciters.first);

    if (reciter.type == ReciterType.snippets) return; // nothing to download
    if (stateFor(reciterId).isDownloading) return;    // already running

    final cancelToken = CancelToken();
    _cancelTokens[reciterId] = cancelToken;

    // Count already downloaded surahs
    int alreadyDone = 0;
    for (int i = 1; i <= 114; i++) {
      if (await _isSurahValid(reciterId, i)) alreadyDone++;
    }

    _states[reciterId] = ReciterDownloadState(
      isDownloading: true,
      downloadedCount: alreadyDone,
      totalCount: 114,
    );
    notifyListeners();

    developer.log('⬇️ Starting download for $reciterId (already: $alreadyDone/114)',
        name: 'ReciterDownload');

    for (int surah = 1; surah <= 114; surah++) {
      if (cancelToken.isCancelled) {
        _states[reciterId] = _states[reciterId]!.copyWith(
          isDownloading: false,
          isCancelled: true,
        );
        notifyListeners();
        developer.log('🚫 Download cancelled for $reciterId at surah $surah',
            name: 'ReciterDownload');
        return;
      }

      // Skip already downloaded
      if (await _isSurahValid(reciterId, surah)) continue;

      _states[reciterId] = _states[reciterId]!.copyWith(
        currentSurah: surah,
      );
      notifyListeners();

      try {
        await _downloadSurah(reciterId, reciter.cdnId!, surah, cancelToken);
        alreadyDone++;
        _states[reciterId] = _states[reciterId]!.copyWith(
          downloadedCount: alreadyDone,
          currentSurah: surah,
        );
        notifyListeners();
        developer.log('✅ Downloaded surah $surah ($alreadyDone/114)',
            name: 'ReciterDownload');
      } on DioException catch (e) {
        if (CancelToken.isCancel(e)) {
          _states[reciterId] = _states[reciterId]!.copyWith(
            isDownloading: false,
            isCancelled: true,
          );
          notifyListeners();
          return;
        }
        developer.log('⚠️ Failed surah $surah: ${e.message}',
            name: 'ReciterDownload');
        // Continue to next surah on error (don't abort entire download)
      } catch (e) {
        developer.log('⚠️ Unexpected error surah $surah: $e',
            name: 'ReciterDownload');
      }
    }

    _states[reciterId] = ReciterDownloadState(
      isDownloading: false,
      downloadedCount: alreadyDone,
      totalCount: 114,
    );
    _cancelTokens.remove(reciterId);
    notifyListeners();
    developer.log('🎉 Download complete for $reciterId ($alreadyDone/114)',
        name: 'ReciterDownload');
    // Re-scan disk to get accurate count (handles partial failures)
    await refreshState(reciterId);
  }

  Future<void> _downloadSurah(
    String reciterId,
    String cdnId,
    int surahNumber,
    CancelToken cancelToken,
  ) async {
    // Use mp3quran.net server if available (more reliable than cdn.islamic.network)
    final reciter = QuranAudioService.reciters.firstWhere(
      (r) => r.id == reciterId,
      orElse: () => QuranAudioService.reciters.first,
    );

    final String url;
    if (reciter.mp3QuranServer != null) {
      final padded = surahNumber.toString().padLeft(3, '0');
      url = '${reciter.mp3QuranServer}$padded.mp3';
    } else {
      url = 'https://cdn.islamic.network/quran/audio-surah/128/$cdnId/$surahNumber.mp3';
    }

    final savePath = await _getLocalPath(reciterId, surahNumber);

    // Ensure directory exists
    final dir = Directory(savePath).parent;
    if (!await dir.exists()) await dir.create(recursive: true);

    await _dio.download(
      url,
      savePath,
      cancelToken: cancelToken,
      options: Options(receiveTimeout: const Duration(minutes: 10)),
    );
  }

  Future<String> _getLocalPath(String reciterId, int surahNumber) async {
    final dir = await getApplicationDocumentsDirectory();
    final paddedNum = surahNumber.toString().padLeft(3, '0');
    return '${dir.path}/quran_audio/$reciterId/$paddedNum.mp3';
  }

  /// Check if a surah file exists and is non-empty (> 10 KB).
  Future<bool> _isSurahValid(String reciterId, int surahNumber) async {
    final path = await _getLocalPath(reciterId, surahNumber);
    final file = File(path);
    if (!await file.exists()) return false;
    final size = await file.length();
    return size > 10240; // > 10 KB — rules out empty/corrupt files
  }

  // ── Cancel ────────────────────────────────────────────────────────────────

  void cancelDownload(String reciterId) {
    _cancelTokens[reciterId]?.cancel('User cancelled');
    _cancelTokens.remove(reciterId);
    _states[reciterId] = (_states[reciterId] ?? const ReciterDownloadState())
        .copyWith(isDownloading: false, isCancelled: true);
    notifyListeners();
    developer.log('🚫 Cancelled download for $reciterId', name: 'ReciterDownload');
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  Future<void> deleteReciter(String reciterId) async {
    cancelDownload(reciterId);
    await QuranAudioService().deleteReciter(reciterId);
    _states[reciterId] = const ReciterDownloadState();
    notifyListeners();
  }

  // ── Storage info ──────────────────────────────────────────────────────────

  Future<double> getDownloadedSizeMb(String reciterId) async {
    final dir = await getApplicationDocumentsDirectory();
    final folder = Directory('${dir.path}/quran_audio/$reciterId');
    if (!await folder.exists()) return 0;
    double total = 0;
    await for (final entity in folder.list()) {
      if (entity is File) {
        total += await entity.length();
      }
    }
    return total / (1024 * 1024);
  }

  /// Refresh download state from disk (call on app start).
  /// Does NOT overwrite an active download state.
  Future<void> refreshState(String reciterId) async {
    final reciter = QuranAudioService.reciters
        .firstWhere((r) => r.id == reciterId, orElse: () => QuranAudioService.reciters.first);
    if (reciter.type == ReciterType.snippets) return;

    // Don't overwrite an active download — it has the live count
    if (stateFor(reciterId).isDownloading) return;

    int count = 0;
    for (int i = 1; i <= 114; i++) {
      if (await _isSurahValid(reciterId, i)) count++;
    }
    _states[reciterId] = ReciterDownloadState(
      downloadedCount: count,
      totalCount: 114,
    );
    notifyListeners();
  }
}
