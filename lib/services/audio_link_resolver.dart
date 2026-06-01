import 'dart:developer' as developer;
import 'package:http/http.dart' as http;
import 'package:soundcloud_explode_dart/soundcloud_explode_dart.dart';

/// Resolves page links (e.g. SoundCloud) into a direct, streamable audio URL.
///
/// `just_audio`/`dio` can only open a direct media file. A page link such as
/// `https://soundcloud.com/user/track` is HTML, so it must be resolved to the
/// underlying stream URL first. Direct media URLs are returned unchanged.
///
/// Note: SoundCloud stream URLs are time-limited, so always resolve right
/// before playing/downloading — never store the resolved URL.
class AudioLinkResolver {
  AudioLinkResolver._();

  static final SoundcloudClient _sc = SoundcloudClient();
  static final http.Client _http = http.Client();

  static bool _isSoundCloud(Uri uri) {
    final host = uri.host.toLowerCase();
    return host.endsWith('soundcloud.com') ||
        host == 'on.soundcloud.com' ||
        host.endsWith('.on.soundcloud.com') ||
        host.endsWith('snd.sc');
  }

  static bool _isRedirectLink(Uri uri) {
    final host = uri.host.toLowerCase();
    return host == 'on.soundcloud.com' ||
        host.endsWith('.on.soundcloud.com') ||
        host.endsWith('snd.sc');
  }

  static Future<String> _expandRedirects(String url) async {
    var current = Uri.parse(url);

    for (var i = 0; i < 8; i++) {
      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers['user-agent'] =
            'Mozilla/5.0 (Linux; Android 10) AppleWebKit/537.36';
      final response = await _http.send(request).timeout(
            const Duration(seconds: 10),
          );
      await response.stream.drain<void>();

      final isRedirect =
          response.statusCode >= 300 && response.statusCode < 400;
      final location = response.headers['location'];
      if (!isRedirect || location == null || location.isEmpty) break;

      current = current.resolve(location);
    }

    return current.toString();
  }

  /// Returns a URL that can be streamed/downloaded directly.
  /// Throws a user-friendly (Arabic) exception when a page link cannot be resolved.
  static Future<String> resolve(String rawUrl) async {
    final url = rawUrl.trim();
    final uri = Uri.tryParse(url);
    if (uri == null) return url;

    if (_isSoundCloud(uri)) {
      try {
        final soundCloudUrl = _isRedirectLink(uri)
            ? await _expandRedirects(url)
            : url;
        final track = await _sc.tracks.getByUrl(soundCloudUrl);
        final streams = await _sc.tracks.getStreams(track.id);
        if (streams.isEmpty) {
          throw Exception('لا يوجد بث متاح لهذا المقطع على SoundCloud');
        }
        final stream = streams.firstWhere(
          (s) =>
              (s.container == 'mp3' || s.container == 'mpeg') &&
              s.protocol == 'progressive',
          orElse: () => streams.firstWhere(
            (s) => s.container == 'mp3' || s.container == 'mpeg',
            orElse: () => streams.first,
          ),
        );
        developer.log(
          '🎧 Resolved SoundCloud link → ${stream.url}',
          name: 'LinkResolver',
        );
        return stream.url.toString();
      } catch (e) {
        developer.log(
          '⚠️ SoundCloud resolve failed: $e',
          name: 'LinkResolver',
        );
        throw Exception(
          'تعذّر تشغيل رابط SoundCloud — تأكد أنه رابط عام وقابل للتشغيل',
        );
      }
    }

    // Already a direct media URL (mp3/m4a/m3u8) — use as-is.
    return url;
  }
}
