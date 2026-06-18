import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:ui';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive/hive.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:path_provider/path_provider.dart';
import 'azan_debug_log.dart';

/// Native MethodChannel for scheduling azan alarms via Android AlarmManager.
/// The native side (Kotlin) handles: AlarmManager → BroadcastReceiver → ForegroundService → MediaPlayer.
const MethodChannel _azanChannel = MethodChannel(
  'com.mahmoudsayed.niyyahtracker/azan',
);

/// Alarm IDs for native AlarmManager (5001-5005 for each prayer).
const int _kAlarmIdFajr = 5001;
const int _kAlarmIdDhuhr = 5002;
const int _kAlarmIdAsr = 5003;
const int _kAlarmIdMaghrib = 5004;
const int _kAlarmIdIsha = 5005;

/// Represents a Muazzin (caller to prayer) with audio assets.
class Muazzin {
  final String id;
  final String nameAr;
  final String nameEn;
  final String description;
  final String folderPath;

  const Muazzin({
    required this.id,
    required this.nameAr,
    required this.nameEn,
    required this.description,
    required this.folderPath,
  });
}

/// Service that manages Azan playback, scheduling, and settings.
class AzanService {
  static final AzanService _instance = AzanService._internal();
  factory AzanService() => _instance;
  AzanService._internal() {
    // Listen for when azan finishes playing to dismiss the notification
    _audioPlayer.playerStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _stopMonitor?.cancel();
        _stopMonitor = null;
        _notificationsPlugin.cancel(4000);
        developer.log(
          '🔇 Azan finished, notification dismissed',
          name: 'AzanService',
        );
      }
    });
  }

  final AudioPlayer _audioPlayer = AudioPlayer();
  late Box _settingsBox;
  Timer? _azanCheckTimer;
  Timer? _stopMonitor; // Monitors if notification was dismissed to stop audio
  StreamSubscription<double>? _volumeSubscription;

  // Use the shared singleton plugin instance
  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // ── Settings Keys ──
  static const String _azanEnabledKey = 'azan_enabled';
  static const String _selectedMuazzinKey = 'selected_muazzin';
  static const String _fajrAzanEnabledKey = 'fajr_azan_enabled';
  static const String _dhuhrAzanEnabledKey = 'dhuhr_azan_enabled';
  static const String _asrAzanEnabledKey = 'asr_azan_enabled';
  static const String _maghribAzanEnabledKey = 'maghrib_azan_enabled';
  static const String _ishaAzanEnabledKey = 'isha_azan_enabled';

  /// Increment this whenever bundled audio filenames or content change.
  /// A mismatch wipes the extracted folder and forces a clean re-extraction,
  /// which is the only reliable way to fix devices that have stale files.
  static const int _audioExtractionVersion = 3;
  static const String _audioExtractionVersionKey = 'audio_extraction_version';

  // ── Notification Channel ──
  static const String azanChannelId = 'azan_channel';
  static const String _azanChannelName = 'الأذان';
  static const String _azanChannelDesc = 'تشغيل الأذان عند دخول وقت الصلاة';

  // ── Available Muazzins ──
  static const List<Muazzin> availableMuazzins = [
    Muazzin(
      id: 'tobar',
      nameAr: 'نصر الدين طوبار',
      nameEn: 'Nasser Al-Din Tobar',
      description: 'من أشهر المؤذنين في مصر والعالم الإسلامي',
      folderPath: 'assets/audio/azan/tobar',
    ),
    Muazzin(
      id: 'makkah',
      nameAr: 'أذان الحرم المكي',
      nameEn: 'Makkah Haram',
      description: 'أذان المسجد الحرام بمكة المكرمة',
      folderPath: 'assets/audio/azan/makkah',
    ),
    Muazzin(
      id: 'madinah',
      nameAr: 'أذان المسجد النبوي',
      nameEn: 'Madinah Mosque',
      description: 'أذان المسجد النبوي الشريف بالمدينة المنورة',
      folderPath: 'assets/audio/azan/madinah',
    ),
    Muazzin(
      id: 'refaat',
      nameAr: 'محمد رفعت',
      nameEn: 'Mohamed Refaat',
      description: 'بصوت الشيخ محمد رفعت رحمه الله',
      folderPath: 'assets/audio/azan/refaat',
    ),
  ];

  /// Initialize the service.
  Future<void> init() async {
    developer.log('🕌 AzanService.init() called', name: 'AzanService');
    try {
      if (!Hive.isBoxOpen('azan_settings')) {
        _settingsBox = await Hive.openBox('azan_settings');
      } else {
        _settingsBox = Hive.box('azan_settings');
      }

      // Extract audio files to app storage for background access
      await _extractAudioFiles();

      // Configure audio session so volume buttons control the azan
      // and interruptions (like phone calls) pause/stop it
      try {
        final session = await AudioSession.instance;
        await session.configure(
          const AudioSessionConfiguration(
            avAudioSessionCategory: AVAudioSessionCategory.playback,
            avAudioSessionCategoryOptions:
                AVAudioSessionCategoryOptions.duckOthers,
            avAudioSessionMode: AVAudioSessionMode.defaultMode,
            androidAudioAttributes: AndroidAudioAttributes(
              contentType: AndroidAudioContentType.music,
              usage: AndroidAudioUsage.alarm,
            ),
            androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
            androidWillPauseWhenDucked: false,
          ),
        );

        // Listen for audio becoming noisy (headphones unplugged) or interruptions
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            // Audio interrupted (phone call, etc.) — stop azan
            developer.log(
              '🔇 Audio interrupted, stopping azan',
              name: 'AzanService',
            );
            stopAzan();
            dismissAzanNotification();
          }
        });

        session.becomingNoisyEventStream.listen((_) {
          developer.log(
            '🔇 Audio becoming noisy, stopping azan',
            name: 'AzanService',
          );
          stopAzan();
          dismissAzanNotification();
        });
      } catch (e) {
        developer.log('⚠️ Audio session config error: $e', name: 'AzanService');
      }

      await _createAzanChannel();
      _startAzanChecker();

      developer.log('✅ AzanService initialized', name: 'AzanService');
    } catch (e, st) {
      developer.log(
        '❌ AzanService.init() error',
        name: 'AzanService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Extract audio files from Flutter assets to app documents directory.
  /// This ensures they are accessible from background isolates.
  ///
  /// Uses a version number stored in Hive. When the version doesn't match
  /// (e.g., after renaming bundled files), the entire azan_audio folder is
  /// wiped and all files are re-extracted from scratch, ensuring no stale
  /// file from a previous install is ever used.
  Future<void> _extractAudioFiles() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final azanDir = Directory('${dir.path}/azan_audio');

      // Version check — wipe everything if the version doesn't match.
      final storedVersion =
          _settingsBox.get(_audioExtractionVersionKey, defaultValue: 0) as int;
      if (storedVersion != _audioExtractionVersion) {
        developer.log(
          '🗑 Audio version mismatch ($storedVersion → $_audioExtractionVersion), '
          'wiping and re-extracting all azan audio',
          name: 'AzanService',
        );
        if (azanDir.existsSync()) {
          azanDir.deleteSync(recursive: true);
        }
      }

      if (!azanDir.existsSync()) {
        azanDir.createSync(recursive: true);
      }

      // All asset files to extract. Key = destination filename in azan_audio/.
      final assets = {
        'tobar_nasreldin.mp3':     'assets/audio/azan/tobar/nasreldin.mp3',
        'tobar_nasreldinfagr.mp3': 'assets/audio/azan/tobar/nasreldinfagr.mp3',
        'makkah_normal.mp3':       'assets/audio/azan/makkah/normal.mp3',
        'makkah_fajr.mp3':         'assets/audio/azan/makkah/fajr.mp3',
        'madinah_normal.mp3':      'assets/audio/azan/madinah/normal.mp3',
        'madinah_fajr.mp3':        'assets/audio/azan/madinah/fajr.mp3',
        'refaat_normal.mp3':       'assets/audio/azan/refaat/normal.mp3',
        'refaat_fajr.mp3':         'assets/audio/azan/refaat/fajr.mp3',
      };

      for (final entry in assets.entries) {
        final outFile = File('${azanDir.path}/${entry.key}');
        if (!outFile.existsSync()) {
          try {
            final data = await rootBundle.load(entry.value);
            await outFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
            developer.log('📁 Extracted ${entry.key}', name: 'AzanService');
          } catch (e) {
            developer.log(
              '⚠️ Failed to extract ${entry.key}: $e',
              name: 'AzanService',
            );
          }
        }
      }

      // Persist the current version so we only wipe once.
      await _settingsBox.put(
          _audioExtractionVersionKey, _audioExtractionVersion);
    } catch (e) {
      developer.log('⚠️ Error extracting audio files: $e', name: 'AzanService');
    }
  }

  /// Called by NotificationService when a notification action is received.

  /// This handles the "stop_azan" action from the notification banner.

  void handleNotificationAction(NotificationResponse response) {
    developer.log(
      '🔔 AzanService handling action: ${response.actionId}',
      name: 'AzanService',
    );

    if (response.actionId == 'stop_azan') {
      unawaited(stopAzan());

      developer.log(
        '⏹️ Azan stopped via notification action',
        name: 'AzanService',
      );
    }
  }

  /// Dismiss the azan notification banner.

  void dismissAzanNotification() {
    _notificationsPlugin.cancel(4000);
    _notificationsPlugin.cancel(4006);
  }

  Future<void> _createAzanChannel() async {
    const channel = AndroidNotificationChannel(
      azanChannelId,

      _azanChannelName,

      description: _azanChannelDesc,

      importance: Importance.max,

      playSound: false,

      enableVibration: true,

      showBadge: true,

      enableLights: true,
    );

    await _notificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);
  }

  // ── Getters ──

  bool get azanEnabled => _settingsBox.get(_azanEnabledKey, defaultValue: true);

  String get selectedMuazzinId =>
      _settingsBox.get(_selectedMuazzinKey, defaultValue: 'tobar');

  Muazzin get selectedMuazzin => availableMuazzins.firstWhere(
    (m) => m.id == selectedMuazzinId,

    orElse: () => availableMuazzins.first,
  );

  bool get fajrAzanEnabled =>
      _settingsBox.get(_fajrAzanEnabledKey, defaultValue: true);

  bool get dhuhrAzanEnabled =>
      _settingsBox.get(_dhuhrAzanEnabledKey, defaultValue: true);

  bool get asrAzanEnabled =>
      _settingsBox.get(_asrAzanEnabledKey, defaultValue: true);

  bool get maghribAzanEnabled =>
      _settingsBox.get(_maghribAzanEnabledKey, defaultValue: true);

  bool get ishaAzanEnabled =>
      _settingsBox.get(_ishaAzanEnabledKey, defaultValue: true);

  bool isPrayerAzanEnabled(String prayerName) {
    switch (prayerName) {
      case 'الفجر':
        return fajrAzanEnabled;

      case 'الظهر':
        return dhuhrAzanEnabled;

      case 'العصر':
        return asrAzanEnabled;

      case 'المغرب':
        return maghribAzanEnabled;

      case 'العشاء':
        return ishaAzanEnabled;

      default:
        return true;
    }
  }

  // ── Setters ──

  Future<void> setAzanEnabled(bool enabled) async {
    await _settingsBox.put(_azanEnabledKey, enabled);

    if (enabled) {
      _startAzanChecker();

      await scheduleAzanNotifications();
    } else {
      _stopAzanChecker();

      await cancelAzanNotifications();

      await stopAzan();
    }
  }

  Future<void> setSelectedMuazzin(String muazzinId) async {
    await _settingsBox.put(_selectedMuazzinKey, muazzinId);

    developer.log(
      '🕌 Selected muazzin changed to: $muazzinId',
      name: 'AzanService',
    );
  }

  Future<void> setFajrAzanEnabled(bool enabled) async {
    await _settingsBox.put(_fajrAzanEnabledKey, enabled);

    await scheduleAzanNotifications();
  }

  Future<void> setDhuhrAzanEnabled(bool enabled) async {
    await _settingsBox.put(_dhuhrAzanEnabledKey, enabled);

    await scheduleAzanNotifications();
  }

  Future<void> setAsrAzanEnabled(bool enabled) async {
    await _settingsBox.put(_asrAzanEnabledKey, enabled);

    await scheduleAzanNotifications();
  }

  Future<void> setMaghribAzanEnabled(bool enabled) async {
    await _settingsBox.put(_maghribAzanEnabledKey, enabled);

    await scheduleAzanNotifications();
  }

  Future<void> setIshaAzanEnabled(bool enabled) async {
    await _settingsBox.put(_ishaAzanEnabledKey, enabled);

    await scheduleAzanNotifications();
  }

  // ── Audio Playback ──

  /// Returns the extracted file path for a muazzin's audio.
  /// Falls back to re-extracting if the file is missing.
  Future<String?> _getExtractedPath(Muazzin muazzin, {required bool isFajr}) async {
    final dir = await getApplicationDocumentsDirectory();
    final azanDir = '${dir.path}/azan_audio';

    final String fileName;
    final String assetPath;
    if (muazzin.id == 'tobar') {
      fileName = isFajr ? 'tobar_nasreldinfagr.mp3' : 'tobar_nasreldin.mp3';
      assetPath = isFajr
          ? 'assets/audio/azan/tobar/nasreldinfagr.mp3'
          : 'assets/audio/azan/tobar/nasreldin.mp3';
    } else {
      final suffix = isFajr ? 'fajr.mp3' : 'normal.mp3';
      fileName = '${muazzin.id}_$suffix';
      assetPath = '${muazzin.folderPath}/$suffix';
    }

    final outFile = File('$azanDir/$fileName');

    // If file is missing (e.g., first launch after Refaat was added), extract it now.
    if (!outFile.existsSync()) {
      try {
        final d = Directory(azanDir);
        if (!d.existsSync()) d.createSync(recursive: true);
        final data = await rootBundle.load(assetPath);
        await outFile.writeAsBytes(data.buffer.asUint8List(), flush: true);
        developer.log('📁 On-demand extracted $fileName', name: 'AzanService');
      } catch (e) {
        developer.log('⚠️ On-demand extract failed for $fileName: $e',
            name: 'AzanService');
        return null;
      }
    }

    return outFile.path;
  }

  /// Play the azan for a specific prayer.
  Future<void> playAzan({required bool isFajr}) async {
    if (!azanEnabled) {
      AzanDebugLog.write('playAzan skipped: azanEnabled=false');
      return;
    }

    try {
      final muazzin = selectedMuazzin;
      final filePath = await _getExtractedPath(muazzin, isFajr: isFajr);

      if (filePath == null) {
        developer.log('❌ No audio file for ${muazzin.id}', name: 'AzanService');
        AzanDebugLog.write('playAzan FAILED: no file path for muazzin=${muazzin.id} isFajr=$isFajr');
        return;
      }

      final fileExists = await File(filePath).exists();
      AzanDebugLog.write(
        'playAzan muazzin=${muazzin.id} isFajr=$isFajr path=$filePath exists=$fileExists',
      );
      if (!fileExists) {
        AzanDebugLog.write('playAzan FAILED: file does not exist on disk');
        return;
      }

      developer.log('🔊 Playing azan from file: $filePath', name: 'AzanService');
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
      AzanDebugLog.write('playAzan started successfully');

      _volumeSubscription?.cancel();
      _volumeSubscription = _audioPlayer.volumeStream.listen((volume) {
        if (volume <= 0.01 && _audioPlayer.playing) {
          developer.log('🔇 Volume reduced to 0, stopping azan', name: 'AzanService');
          stopAzan();
          dismissAzanNotification();
          _volumeSubscription?.cancel();
        }
      });
    } catch (e, st) {
      developer.log('❌ Error playing azan', name: 'AzanService', error: e, stackTrace: st);
      AzanDebugLog.write('playAzan EXCEPTION: $e');
    }
  }

  /// Preview a muazzin's azan sound.
  Future<void> previewAzan(String muazzinId, {bool isFajr = false}) async {
    try {
      final muazzin = availableMuazzins.firstWhere(
        (m) => m.id == muazzinId,
        orElse: () => availableMuazzins.first,
      );

      final filePath = await _getExtractedPath(muazzin, isFajr: isFajr);

      if (filePath == null) {
        developer.log('❌ No preview file for ${muazzin.id}', name: 'AzanService');
        return;
      }

      developer.log('🔊 Previewing azan from file: $filePath', name: 'AzanService');
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e, st) {
      developer.log('❌ Error previewing azan', name: 'AzanService', error: e, stackTrace: st);
    }
  }

  /// Stop the currently playing azan (both Flutter and native).

  Future<void> stopAzan() async {
    _volumeSubscription?.cancel();
    _volumeSubscription = null;
    _stopMonitor?.cancel();
    _stopMonitor = null;

    try {
      await _notificationsPlugin.cancel(4000);
      await _notificationsPlugin.cancel(4006);
    } catch (_) {}

    try {
      developer.log(
        '⏹️ stopAzan called, playing=${_audioPlayer.playing}',
        name: 'AzanService',
      );

      await _audioPlayer.setVolume(0);
      await _audioPlayer.pause();
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
    } catch (e) {
      developer.log('❌ Error stopping azan: $e', name: 'AzanService');

      try {
        await _audioPlayer.setVolume(0);
        await _audioPlayer.pause();
        await _audioPlayer.stop();
      } catch (_) {}
    }

    // Also stop native foreground service if playing
    try {
      await _azanChannel.invokeMethod('stopAzan');
    } catch (_) {}

    try {
      await _notificationsPlugin.cancel(4000);
      await _notificationsPlugin.cancel(4006);
    } catch (_) {}
  }

  bool get isPlaying => _audioPlayer.playing;

  // ── Prayer Times & Scheduling ──

  /// Get current prayer times based on user location.

  Future<PrayerTimes> _getPrayerTimes() async {
    Coordinates coords = Coordinates(30.0444, 31.2357); // Default: Cairo

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();

      if (serviceEnabled) {
        LocationPermission permission = await Geolocator.checkPermission();

        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          Position pos = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.low,
            ),
          );

          coords = Coordinates(pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      developer.log(
        '📍 Location error, using Cairo default',
        name: 'AzanService',
        error: e,
      );
    }

    final params = CalculationMethod.egyptian.getParameters()
      ..madhab = Madhab.shafi;

    final pt = PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
    AzanDebugLog.write(
      'PrayerTimes coords=(${coords.latitude.toStringAsFixed(4)},${coords.longitude.toStringAsFixed(4)}) '
      'fajr=${pt.fajr} dhuhr=${pt.dhuhr} asr=${pt.asr} maghrib=${pt.maghrib} isha=${pt.isha}',
    );
    return pt;
  }

  /// Start a periodic timer that checks if it's time for azan.

  void _startAzanChecker() {
    _azanCheckTimer?.cancel();

    if (!azanEnabled) return;

    _azanCheckTimer = Timer.periodic(const Duration(seconds: 30), (_) async {
      await _checkAndPlayAzan();
    });

    developer.log('⏰ Azan checker started', name: 'AzanService');
  }

  void _stopAzanChecker() {
    _azanCheckTimer?.cancel();

    _azanCheckTimer = null;

    developer.log('⏰ Azan checker stopped', name: 'AzanService');
  }

  /// Check if current time matches any prayer time and play azan.
  Future<void> _checkAndPlayAzan() async {
    if (!azanEnabled) return;

    try {
      // Skip if native service is already playing (notification ID 4006)
      try {
        final active = await _notificationsPlugin.getActiveNotifications();
        if (active.any((n) => n.id == 4006)) {
          AzanDebugLog.write('_checkAndPlayAzan: native service active, skipping');
          return;
        }
      } catch (_) {}
      AzanDebugLog.write('_checkAndPlayAzan tick at ${DateTime.now()}');

      final pt = await _getPrayerTimes();
      final now = DateTime.now();

      final prayers = [
        {'name': 'الفجر', 'time': pt.fajr, 'isFajr': true},
        {'name': 'الظهر', 'time': pt.dhuhr, 'isFajr': false},
        {'name': 'العصر', 'time': pt.asr, 'isFajr': false},
        {'name': 'المغرب', 'time': pt.maghrib, 'isFajr': false},
        {'name': 'العشاء', 'time': pt.isha, 'isFajr': false},
      ];

      for (final prayer in prayers) {
        final prayerTime = prayer['time'] as DateTime;
        final prayerName = prayer['name'] as String;
        final isFajr = prayer['isFajr'] as bool;

        // Check if we're within 30 seconds of prayer time
        final diff = now.difference(prayerTime).inSeconds.abs();
        final enabled = isPrayerAzanEnabled(prayerName);
        if (diff <= 30 && enabled) {
          // Avoid playing if already playing
          if (!_audioPlayer.playing) {
            // Dedup: skip if background alarm already played recently
            final lastPlayedMs =
                _settingsBox.get('last_azan_played_ms', defaultValue: 0) as int;
            final nowMs = DateTime.now().millisecondsSinceEpoch;
            if (nowMs - lastPlayedMs < 120000) {
              developer.log(
                '⏭️ Azan recently played (dedup), skipping timer',
                name: 'AzanService',
              );
              AzanDebugLog.write('_checkAndPlayAzan: $prayerName dedup-skipped (last played ${nowMs - lastPlayedMs}ms ago)');
              break;
            }
            await _settingsBox.put('last_azan_played_ms', nowMs);

            developer.log('🕌 Time for $prayerName azan!', name: 'AzanService');
            AzanDebugLog.write('_checkAndPlayAzan: MATCH $prayerName diff=${diff}s → playing');

            await _showAzanNotification(prayerName);

            await playAzan(isFajr: isFajr);
          } else {
            AzanDebugLog.write('_checkAndPlayAzan: $prayerName match but audioPlayer already playing');
          }
          break;
        } else if (diff <= 120) {
          AzanDebugLog.write('_checkAndPlayAzan: $prayerName diff=${diff}s enabled=$enabled (not within 30s or disabled)');
        }
      }
    } catch (e, st) {
      developer.log(
        '❌ Error in _checkAndPlayAzan',
        name: 'AzanService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Show a heads-up banner notification when azan starts.

  /// This appears as a floating banner on top of everything, even outside the app.

  /// Includes a "Stop Azan" action button.

  Future<void> _showAzanNotification(String prayerName) async {
    try {
      await _notificationsPlugin.show(
        4000,

        '🕌 حان وقت صلاة $prayerName',

        'الله أكبر الله أكبر - حان الآن موعد أذان $prayerName',

        NotificationDetails(
          android: AndroidNotificationDetails(
            azanChannelId,

            _azanChannelName,

            channelDescription: _azanChannelDesc,

            importance: Importance.max,

            priority: Priority.max,

            icon: '@mipmap/ic_launcher',

            enableVibration: true,

            playSound: false,

            ongoing: false,

            autoCancel: true,

            fullScreenIntent: true,

            category: AndroidNotificationCategory.alarm,

            visibility: NotificationVisibility.public,

            ticker: 'حان وقت صلاة $prayerName',

            styleInformation: BigTextStyleInformation(
              'الله أكبر الله أكبر\nأشهد أن لا إله إلا الله\nحان الآن موعد أذان $prayerName',

              contentTitle: '🕌 حان وقت صلاة $prayerName',

              summaryText: 'بصائر - أوقات الصلاة',

              htmlFormatBigText: false,
            ),

            timeoutAfter: 300000,

            colorized: true,

            color: const Color(0xFF1B7A4E),

            actions: <AndroidNotificationAction>[
              const AndroidNotificationAction(
                'stop_azan',

                'إيقاف الأذان ⏹',

                showsUserInterface: false,

                cancelNotification: true,
              ),
            ],
          ),

          iOS: const DarwinNotificationDetails(
            presentAlert: true,

            presentBadge: true,

            presentSound: false,

            interruptionLevel: InterruptionLevel.timeSensitive,
          ),
        ),

        payload: 'azan_$prayerName',
      );

      // Start monitoring: if notification gets dismissed (user pressed stop),

      // stop the audio. This is the reliable way since background isolate

      // can't access the same AudioPlayer instance.

      _startStopMonitor();
    } catch (e) {
      developer.log(
        '❌ Error showing azan notification',
        name: 'AzanService',
        error: e,
      );
    }
  }

  /// Polls every 500ms to check if the azan notification was dismissed.
  /// If dismissed while audio is still playing, it means user pressed "Stop".
  void _startStopMonitor() {
    _stopMonitor?.cancel();
    _stopMonitor = Timer.periodic(const Duration(milliseconds: 500), (
      timer,
    ) async {
      if (!_audioPlayer.playing) {
        timer.cancel();
        _stopMonitor = null;
        return;
      }

      try {
        final pending = await _notificationsPlugin.getActiveNotifications();
        final flutterNotifExists = pending.any((n) => n.id == 4000);
        final nativeNotifExists = pending.any((n) => n.id == 4006);

        if (!flutterNotifExists || !nativeNotifExists) {
          // Notification was dismissed (user pressed stop button)
          developer.log(
            '⏹️ Notification dismissed, stopping audio',
            name: 'AzanService',
          );
          timer.cancel();
          _stopMonitor = null;
          await stopAzan();
        }
      } catch (e) {
        developer.log('⚠️ Stop monitor error: $e', name: 'AzanService');
      }
    });
  }

  /// Get the file path for a prayer's azan audio (from extracted app storage).
  Future<String> _getAzanFilePath({required bool isFajr}) async {
    final muazzin = selectedMuazzin;
    final dir = await getApplicationDocumentsDirectory();
    final azanDir = '${dir.path}/azan_audio';
    if (muazzin.id == 'tobar') {
      return isFajr
          ? '$azanDir/tobar_nasreldinfagr.mp3'
          : '$azanDir/tobar_nasreldin.mp3';
    } else {
      final fileName = isFajr ? 'fajr.mp3' : 'normal.mp3';
      return '$azanDir/${muazzin.id}_$fileName';
    }
  }

  /// Schedule azan alarms and notifications for all enabled prayers.
  /// Uses native Android AlarmManager → BroadcastReceiver → ForegroundService → MediaPlayer
  /// for reliable background audio playback.
  Future<void> scheduleAzanNotifications() async {
    if (!azanEnabled) {
      AzanDebugLog.write('scheduleAzanNotifications: skipped (azanEnabled=false)');
      return;
    }
    AzanDebugLog.write('scheduleAzanNotifications: called');

    try {
      // Cancel existing azan notifications and alarms
      await cancelAzanNotifications();

      final pt = await _getPrayerTimes();

      final prayers = [
        {
          'name': 'الفجر',
          'time': pt.fajr,
          'notifId': 4001,
          'alarmId': _kAlarmIdFajr,
          'enabled': fajrAzanEnabled,
          'isFajr': true,
        },
        {
          'name': 'الظهر',
          'time': pt.dhuhr,
          'notifId': 4002,
          'alarmId': _kAlarmIdDhuhr,
          'enabled': dhuhrAzanEnabled,
          'isFajr': false,
        },
        {
          'name': 'العصر',
          'time': pt.asr,
          'notifId': 4003,
          'alarmId': _kAlarmIdAsr,
          'enabled': asrAzanEnabled,
          'isFajr': false,
        },
        {
          'name': 'المغرب',
          'time': pt.maghrib,
          'notifId': 4004,
          'alarmId': _kAlarmIdMaghrib,
          'enabled': maghribAzanEnabled,
          'isFajr': false,
        },
        {
          'name': 'العشاء',
          'time': pt.isha,
          'notifId': 4005,
          'alarmId': _kAlarmIdIsha,
          'enabled': ishaAzanEnabled,
          'isFajr': false,
        },
      ];

      for (final prayer in prayers) {
        if (!(prayer['enabled'] as bool)) continue;

        DateTime prayerTime = prayer['time'] as DateTime;
        if (prayerTime.isBefore(DateTime.now())) {
          prayerTime = prayerTime.add(const Duration(days: 1));
        }

        final prayerName = prayer['name'] as String;
        final notifId = prayer['notifId'] as int;
        final alarmId = prayer['alarmId'] as int;
        final isFajr = prayer['isFajr'] as bool;

        // Get file path for this prayer's azan audio
        final filePath = await _getAzanFilePath(isFajr: isFajr);
        final fileExists = filePath != null && await File(filePath).exists();
        AzanDebugLog.write(
          'schedule $prayerName at $prayerTime filePath=$filePath fileExists=$fileExists',
        );

        // ── PRIMARY: Schedule native Android alarm (plays audio via ForegroundService) ──
        try {
          await _azanChannel.invokeMethod('scheduleAzan', {
            'alarmId': alarmId,
            'triggerAtMs': prayerTime.millisecondsSinceEpoch,
            'filePath': filePath,
            'prayerName': prayerName,
          });
          developer.log(
            '⏰ Native alarm scheduled for $prayerName at $prayerTime (id=$alarmId)',
            name: 'AzanService',
          );
          AzanDebugLog.write('native alarm OK for $prayerName alarmId=$alarmId triggerMs=${prayerTime.millisecondsSinceEpoch}');
        } catch (e) {
          developer.log(
            '⚠️ Native alarm scheduling failed for $prayerName: $e',
            name: 'AzanService',
          );
          AzanDebugLog.write('native alarm FAILED for $prayerName: $e');
        }

        // ── FALLBACK: Schedule zonedSchedule notification (visual only) ──
        final tzTime = tz.TZDateTime.from(prayerTime, tz.local);
        await _notificationsPlugin.zonedSchedule(
          notifId,
          '🕌 حان وقت صلاة $prayerName',
          'الله أكبر الله أكبر - حان الآن موعد أذان $prayerName',
          tzTime,
          NotificationDetails(
            android: AndroidNotificationDetails(
              azanChannelId,
              _azanChannelName,
              channelDescription: _azanChannelDesc,
              importance: Importance.max,
              priority: Priority.max,
              icon: '@mipmap/ic_launcher',
              enableVibration: true,
              playSound: false,
              fullScreenIntent: true,
              category: AndroidNotificationCategory.alarm,
              visibility: NotificationVisibility.public,
              ticker: 'حان وقت صلاة $prayerName',
              styleInformation: BigTextStyleInformation(
                'الله أكبر الله أكبر\nأشهد أن لا إله إلا الله\nحان الآن موعد أذان $prayerName',
                contentTitle: '🕌 حان وقت صلاة $prayerName',
                summaryText: 'بصائر - أوقات الصلاة',
              ),
              timeoutAfter: 60000,
              colorized: true,
              color: const Color(0xFF1B7A4E),
              actions: <AndroidNotificationAction>[
                const AndroidNotificationAction(
                  'stop_azan',
                  'إيقاف الأذان ⏹',
                  showsUserInterface: false,
                  cancelNotification: true,
                ),
              ],
            ),
            iOS: const DarwinNotificationDetails(
              presentAlert: true,
              presentBadge: true,
              presentSound: false,
              interruptionLevel: InterruptionLevel.timeSensitive,
            ),
          ),
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time,
        );

        developer.log(
          '📅 Scheduled azan for $prayerName at $tzTime',
          name: 'AzanService',
        );
      }
    } catch (e, st) {
      developer.log(
        '❌ Error scheduling azan notifications',
        name: 'AzanService',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Cancel all azan notifications and native AlarmManager alarms.
  Future<void> cancelAzanNotifications() async {
    developer.log('🔕 cancelAzanNotifications() called', name: 'AzanService');
    // Cancel scheduled notifications
    for (int id = 4000; id <= 4006; id++) {
      try {
        await _notificationsPlugin.cancel(id);
        developer.log('🔕 Cancelled notification id=$id', name: 'AzanService');
      } catch (e, st) {
        developer.log(
          '❌ Failed to cancel notification id=$id',
          name: 'AzanService',
          error: e,
          stackTrace: st,
        );
      }
    }
    // Cancel native AlarmManager alarms
    try {
      await _azanChannel.invokeMethod('cancelAllAzan');
      developer.log('🔕 Native cancelAllAzan succeeded', name: 'AzanService');
    } catch (e, st) {
      developer.log(
        '❌ Native cancelAllAzan failed',
        name: 'AzanService',
        error: e,
        stackTrace: st,
      );
    }
  }

  // ── Test / Debug helpers ──

  /// Immediately plays the azan through Flutter's audio player.
  /// Bypasses the azanEnabled guard so it works even when disabled.
  Future<void> testFlutterAzan() async {
    AzanDebugLog.write('TEST: testFlutterAzan() called');
    try {
      final muazzin = selectedMuazzin;
      final filePath = await _getExtractedPath(muazzin, isFajr: false);
      if (filePath == null) {
        AzanDebugLog.write('TEST: no file path for muazzin=${muazzin.id}');
        return;
      }
      final exists = await File(filePath).exists();
      AzanDebugLog.write('TEST: Flutter path=$filePath exists=$exists');
      if (!exists) return;
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
      AzanDebugLog.write('TEST: Flutter audio.play() called OK');
    } catch (e) {
      AzanDebugLog.write('TEST: testFlutterAzan EXCEPTION: $e');
    }
  }

  /// Schedules a native AlarmManager alarm [delaySeconds] from now.
  /// Fires the full native chain: BroadcastReceiver → ForegroundService → MediaPlayer.
  Future<String> testNativeAlarm({int delaySeconds = 15}) async {
    AzanDebugLog.write('TEST: testNativeAlarm() delay=$delaySeconds');
    try {
      final filePath = await _getAzanFilePath(isFajr: false);
      final exists = await File(filePath).exists();
      AzanDebugLog.write('TEST: native path=$filePath exists=$exists');
      final triggerMs = DateTime.now().millisecondsSinceEpoch + (delaySeconds * 1000);
      await _azanChannel.invokeMethod('scheduleAzan', {
        'alarmId': 9999,
        'triggerAtMs': triggerMs,
        'filePath': filePath,
        'prayerName': 'اختبار الأذان',
      });
      AzanDebugLog.write('TEST: native alarm scheduled for ${delaySeconds}s from now');
      return 'تم جدولة الأذان الأصلي بعد $delaySeconds ثانية';
    } catch (e) {
      AzanDebugLog.write('TEST: testNativeAlarm FAILED: $e');
      return 'فشل جدولة الأذان الأصلي: $e';
    }
  }

  /// Dispose resources.

  void dispose() {
    _azanCheckTimer?.cancel();

    _stopMonitor?.cancel();

    _volumeSubscription?.cancel();

    _audioPlayer.dispose();
  }
}
