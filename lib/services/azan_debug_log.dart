import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Persistent file-based logger for azan debug events.
/// Writes to {filesDir}/azan_debug.log — readable from both Dart and native Kotlin.
/// Survives app restarts and works in release builds.
class AzanDebugLog {
  static const _fileName = 'azan_debug.log';
  static const _maxLines = 300;

  static Future<File> _file() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/$_fileName');
  }

  static Future<void> write(String message) async {
    try {
      final file = await _file();
      final now = DateTime.now();
      final ts =
          '${now.year}-${_p(now.month)}-${_p(now.day)} '
          '${_p(now.hour)}:${_p(now.minute)}:${_p(now.second)}';
      await file.writeAsString(
        '[$ts] [Flutter] $message\n',
        mode: FileMode.append,
        flush: true,
      );
      _trim(file);
    } catch (_) {}
  }

  static Future<String> read() async {
    try {
      final file = await _file();
      if (!await file.exists()) return '(no logs yet)\n';
      final content = await file.readAsString();
      return content.isEmpty ? '(no logs yet)\n' : content;
    } catch (e) {
      return 'Error reading log: $e\n';
    }
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      await file.writeAsString('', flush: true);
    } catch (_) {}
  }

  static Future<String> filePath() async {
    final f = await _file();
    return f.path;
  }

  static void _trim(File file) async {
    try {
      final lines = await file.readAsLines();
      if (lines.length > _maxLines) {
        await file.writeAsString(
          '${lines.skip(lines.length - _maxLines).join('\n')}\n',
          flush: true,
        );
      }
    } catch (_) {}
  }

  static String _p(int n) => n.toString().padLeft(2, '0');
}
