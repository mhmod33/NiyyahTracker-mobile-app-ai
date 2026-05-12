import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:just_audio/just_audio.dart';
import 'package:audio_session/audio_session.dart';
import 'package:hive/hive.dart';
import 'package:adhan/adhan.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

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
        developer.log('🔇 Azan finished, notification dismissed', name: 'AzanService');
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

      // Configure audio session so volume buttons control the azan
      // and interruptions (like phone calls) pause/stop it
      try {
        final session = await AudioSession.instance;
        await session.configure(const AudioSessionConfiguration(
          avAudioSessionCategory: AVAudioSessionCategory.playback,
          avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.duckOthers,
          avAudioSessionMode: AVAudioSessionMode.defaultMode,
          androidAudioAttributes: AndroidAudioAttributes(
            contentType: AndroidAudioContentType.music,
            usage: AndroidAudioUsage.media,
          ),
          androidAudioFocusGainType: AndroidAudioFocusGainType.gain,
          androidWillPauseWhenDucked: false,
        ));

        // Listen for audio becoming noisy (headphones unplugged) or interruptions
        session.interruptionEventStream.listen((event) {
          if (event.begin) {
            // Audio interrupted (phone call, etc.) — stop azan
            developer.log('🔇 Audio interrupted, stopping azan', name: 'AzanService');
            stopAzan();
            dismissAzanNotification();
          }
        });

        session.becomingNoisyEventStream.listen((_) {
          developer.log('🔇 Audio becoming noisy, stopping azan', name: 'AzanService');
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
      developer.log('❌ AzanService.init() error', name: 'AzanService', error: e, stackTrace: st);
    }
  }

  /// Called by NotificationService when a notification action is received.
  /// This handles the "stop_azan" action from the notification banner.
  void handleNotificationAction(NotificationResponse response) {
    developer.log('🔔 AzanService handling action: ${response.actionId}', name: 'AzanService');
    if (response.actionId == 'stop_azan') {
      _audioPlayer.pause();
      _audioPlayer.stop();
      _volumeSubscription?.cancel();
      _volumeSubscription = null;
      _stopMonitor?.cancel();
      _stopMonitor = null;
      dismissAzanNotification();
      developer.log('⏹️ Azan stopped via notification action', name: 'AzanService');
    }
  }

  /// Dismiss the azan notification banner.
  void dismissAzanNotification() {
    _notificationsPlugin.cancel(4000);
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
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);
  }

  // ── Getters ──

  bool get azanEnabled => _settingsBox.get(_azanEnabledKey, defaultValue: true);

  String get selectedMuazzinId =>
      _settingsBox.get(_selectedMuazzinKey, defaultValue: 'tobar');

  Muazzin get selectedMuazzin =>
      availableMuazzins.firstWhere(
        (m) => m.id == selectedMuazzinId,
        orElse: () => availableMuazzins.first,
      );

  bool get fajrAzanEnabled => _settingsBox.get(_fajrAzanEnabledKey, defaultValue: true);
  bool get dhuhrAzanEnabled => _settingsBox.get(_dhuhrAzanEnabledKey, defaultValue: true);
  bool get asrAzanEnabled => _settingsBox.get(_asrAzanEnabledKey, defaultValue: true);
  bool get maghribAzanEnabled => _settingsBox.get(_maghribAzanEnabledKey, defaultValue: true);
  bool get ishaAzanEnabled => _settingsBox.get(_ishaAzanEnabledKey, defaultValue: true);

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
    developer.log('🕌 Selected muazzin changed to: $muazzinId', name: 'AzanService');
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

  /// Play the azan for a specific prayer.
  Future<void> playAzan({required bool isFajr}) async {
    if (!azanEnabled) return;

    try {
      final muazzin = selectedMuazzin;
      final String assetPath;
      
      if (muazzin.id == 'tobar') {
        assetPath = isFajr
            ? 'assets/audio/azan/tobar/nasreldinfagr.mp3'
            : 'assets/audio/azan/tobar/nasreldin.mp3';
      } else {
        final fileName = isFajr ? 'fajr.mp3' : 'normal.mp3';
        assetPath = '${muazzin.folderPath}/$fileName';
      }

      developer.log('🔊 Playing azan: $assetPath', name: 'AzanService');

      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();

      // Monitor volume — if user lowers volume to 0, stop the azan
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
    }
  }

  /// Preview a muazzin's azan sound.
  Future<void> previewAzan(String muazzinId, {bool isFajr = false}) async {
    try {
      final muazzin = availableMuazzins.firstWhere(
        (m) => m.id == muazzinId,
        orElse: () => availableMuazzins.first,
      );
      final String assetPath;

      if (muazzin.id == 'tobar') {
        assetPath = isFajr
            ? 'assets/audio/azan/tobar/nasreldinfagr.mp3'
            : 'assets/audio/azan/tobar/nasreldin.mp3';
      } else {
        final fileName = isFajr ? 'fajr.mp3' : 'normal.mp3';
        assetPath = '${muazzin.folderPath}/$fileName';
      }

      developer.log('🔊 Previewing azan: $assetPath', name: 'AzanService');

      await _audioPlayer.setAsset(assetPath);
      await _audioPlayer.setVolume(1.0);
      await _audioPlayer.play();
    } catch (e, st) {
      developer.log('❌ Error previewing azan', name: 'AzanService', error: e, stackTrace: st);
    }
  }

  /// Stop the currently playing azan.
  Future<void> stopAzan() async {
    try {
      developer.log('⏹️ stopAzan called, playing=${_audioPlayer.playing}', name: 'AzanService');
      _volumeSubscription?.cancel();
      _volumeSubscription = null;
      _stopMonitor?.cancel();
      _stopMonitor = null;
      if (_audioPlayer.playing) {
        await _audioPlayer.pause();
      }
      await _audioPlayer.stop();
      await _audioPlayer.seek(Duration.zero);
    } catch (e) {
      developer.log('❌ Error stopping azan: $e', name: 'AzanService');
      try {
        await _audioPlayer.setVolume(0);
        await _audioPlayer.pause();
      } catch (_) {}
    }
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
            locationSettings: const LocationSettings(accuracy: LocationAccuracy.low),
          );
          coords = Coordinates(pos.latitude, pos.longitude);
        }
      }
    } catch (e) {
      developer.log('📍 Location error, using Cairo default', name: 'AzanService', error: e);
    }

    final params = CalculationMethod.egyptian.getParameters()..madhab = Madhab.shafi;
    return PrayerTimes(coords, DateComponents.from(DateTime.now()), params);
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
        if (diff <= 30 && isPrayerAzanEnabled(prayerName)) {
          // Avoid playing if already playing
          if (!_audioPlayer.playing) {
            developer.log('🕌 Time for $prayerName azan!', name: 'AzanService');
            await _showAzanNotification(prayerName);
            await playAzan(isFajr: isFajr);
          }
          break;
        }
      }
    } catch (e, st) {
      developer.log('❌ Error in _checkAndPlayAzan', name: 'AzanService', error: e, stackTrace: st);
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
            ongoing: true,
            autoCancel: false,
            fullScreenIntent: true,
            category: AndroidNotificationCategory.alarm,
            visibility: NotificationVisibility.public,
            ticker: 'حان وقت صلاة $prayerName',
            styleInformation: BigTextStyleInformation(
              'الله أكبر الله أكبر\nأشهد أن لا إله إلا الله\nحان الآن موعد أذان $prayerName',
              contentTitle: '🕌 حان وقت صلاة $prayerName',
              summaryText: 'النية - أوقات الصلاة',
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
      developer.log('❌ Error showing azan notification', name: 'AzanService', error: e);
    }
  }

  /// Polls every 500ms to check if the azan notification was dismissed.
  /// If dismissed while audio is still playing, it means user pressed "Stop".
  void _startStopMonitor() {
    _stopMonitor?.cancel();
    _stopMonitor = Timer.periodic(const Duration(milliseconds: 500), (timer) async {
      if (!_audioPlayer.playing) {
        timer.cancel();
        _stopMonitor = null;
        return;
      }

      try {
        final pending = await _notificationsPlugin.getActiveNotifications();
        final azanNotifExists = pending.any((n) => n.id == 4000);

        if (!azanNotifExists) {
          // Notification was dismissed (user pressed stop button)
          developer.log('⏹️ Notification dismissed, stopping audio', name: 'AzanService');
          await _audioPlayer.pause();
          await _audioPlayer.stop();
          _volumeSubscription?.cancel();
          _volumeSubscription = null;
          timer.cancel();
          _stopMonitor = null;
        }
      } catch (e) {
        developer.log('⚠️ Stop monitor error: $e', name: 'AzanService');
      }
    });
  }

  /// Schedule azan notifications for all enabled prayers.
  Future<void> scheduleAzanNotifications() async {
    if (!azanEnabled) return;

    try {
      // Cancel existing azan notifications
      await cancelAzanNotifications();

      final pt = await _getPrayerTimes();

      final prayers = [
        {'name': 'الفجر', 'time': pt.fajr, 'id': 4001, 'enabled': fajrAzanEnabled},
        {'name': 'الظهر', 'time': pt.dhuhr, 'id': 4002, 'enabled': dhuhrAzanEnabled},
        {'name': 'العصر', 'time': pt.asr, 'id': 4003, 'enabled': asrAzanEnabled},
        {'name': 'المغرب', 'time': pt.maghrib, 'id': 4004, 'enabled': maghribAzanEnabled},
        {'name': 'العشاء', 'time': pt.isha, 'id': 4005, 'enabled': ishaAzanEnabled},
      ];

      for (final prayer in prayers) {
        if (!(prayer['enabled'] as bool)) continue;

        DateTime prayerTime = prayer['time'] as DateTime;
        if (prayerTime.isBefore(DateTime.now())) {
          prayerTime = prayerTime.add(const Duration(days: 1));
        }

        final tzTime = tz.TZDateTime.from(prayerTime, tz.local);
        final prayerName = prayer['name'] as String;
        final id = prayer['id'] as int;

        await _notificationsPlugin.zonedSchedule(
          id,
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
                summaryText: 'النية - أوقات الصلاة',
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

        developer.log('📅 Scheduled azan for $prayerName at $tzTime', name: 'AzanService');
      }
    } catch (e, st) {
      developer.log('❌ Error scheduling azan notifications', name: 'AzanService', error: e, stackTrace: st);
    }
  }

  /// Cancel all azan notifications.
  Future<void> cancelAzanNotifications() async {
    for (int id = 4000; id <= 4005; id++) {
      await _notificationsPlugin.cancel(id);
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
