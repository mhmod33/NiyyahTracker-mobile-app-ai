import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'quran_audio_service.dart';

/// Shared audio library via Firestore only (no Firebase Storage / Blaze plan).
/// Audio is split into base64 chunks under each track document.
class SharedLibraryService {
  static final SharedLibraryService _instance = SharedLibraryService._();
  factory SharedLibraryService() => _instance;
  SharedLibraryService._();

  static const String collection = 'library_snippets';
  static const String chunksSubcollection = 'chunks';

  static const Duration metaWriteTimeout = Duration(seconds: 30);
  static const Duration fetchTimeout = Duration(seconds: 45);

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final _uuid = const Uuid();

  static String reciterIdFor(String name) {
    final slug = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r"[^a-z0-9_\u0600-\u06FF]"), '');
    return 'shared_${slug.isEmpty ? 'reciter' : slug}';
  }

  String _firestoreErrorMessage(Object e) {
    if (e is FirebaseException) {
      switch (e.code) {
        case 'permission-denied':
          return 'لا صلاحية للرفع — تأكد أن حسابك مسجّل كمسؤول في Firestore';
        case 'unavailable':
          return 'الخدمة غير متاحة — تحقق من الاتصال بالإنترنت';
        case 'deadline-exceeded':
          return 'انتهت مهلة الاتصال — جرّب ملفاً أصغر أو شبكة أسرع';
        default:
          return 'خطأ Firestore (${e.code}): ${e.message ?? e.toString()}';
      }
    }
    if (e is TimeoutException) {
      return 'انتهت مهلة الرفع — تحقق من الاتصال وحاول مرة أخرى';
    }
    return e.toString();
  }

  /// Add a snippet that streams from a direct audio URL (admin only — Firestore rules).
  /// Writes a single lightweight metadata doc — no audio bytes are stored.
  Future<void> addLinkSnippet({
    required String reciterName,
    required String trackTitle,
    required String remoteUrl,
    required String uploadedByUid,
    required String uploadedByName,
  }) async {
    final url = remoteUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw Exception('رابط غير صالح — يجب أن يبدأ بـ http أو https');
    }

    final trackId = _uuid.v4();
    final reciterId = reciterIdFor(reciterName);

    try {
      await _db
          .collection(collection)
          .doc(trackId)
          .set({
            'reciterId': reciterId,
            'reciterNameAr': reciterName.trim(),
            'title': trackTitle.trim(),
            'remoteUrl': url,
            'uploadedBy': uploadedByUid,
            'uploadedByName': uploadedByName,
            'createdAt': FieldValue.serverTimestamp(),
            'encoding': 'link',
          })
          .timeout(metaWriteTimeout);

      developer.log(
        '🔗 Shared link snippet added: $trackId ($url)',
        name: 'SharedLibrary',
      );
    } catch (e, st) {
      developer.log('⚠️ addLinkSnippet failed',
          name: 'SharedLibrary', error: e, stackTrace: st);
      throw Exception(_firestoreErrorMessage(e));
    }
  }

  /// Fetch all shared snippets grouped as [Reciter]s (metadata only).
  Future<List<Reciter>> fetchSharedReciters() async {
    try {
      final snap =
          await _db.collection(collection).get().timeout(fetchTimeout);

      final Map<String, List<SnippetTrack>> byReciter = {};
      final Map<String, String> names = {};
      final Map<String, String> descriptions = {};

      for (final doc in snap.docs) {
        final d = doc.data();
        final reciterId = d['reciterId'] as String? ?? 'shared_unknown';
        final nameAr = d['reciterNameAr'] as String? ?? 'مقتطفات بصائر';
        final title = d['title'] as String? ?? 'مقطع';

        names[reciterId] = nameAr;
        descriptions[reciterId] = 'مقتطفات مشتركة — متاحة للجميع';

        byReciter.putIfAbsent(reciterId, () => []);
        byReciter[reciterId]!.add(SnippetTrack(
          title: title,
          assetPath: '',
          remoteUrl: d['remoteUrl'] as String? ?? '',
          reciterId: reciterId,
          cloudTrackId: doc.id,
        ));
      }

      return byReciter.entries
          .map((e) => Reciter(
                id: e.key,
                nameAr: names[e.key]!,
                nameEn: '',
                description: descriptions[e.key]!,
                type: ReciterType.snippets,
                snippetTracks: e.value,
              ))
          .toList();
    } catch (e, st) {
      developer.log('⚠️ fetchSharedReciters failed',
          name: 'SharedLibrary', error: e, stackTrace: st);
      return [];
    }
  }

  /// Download chunks from Firestore and save locally. Returns path when ready.
  Future<String?> ensureTrackCached(String cloudTrackId) async {
    final outPath = await cachedFilePath(cloudTrackId);
    if (await File(outPath).exists()) return outPath;

    try {
      final trackDoc = await _db
          .collection(collection)
          .doc(cloudTrackId)
          .get()
          .timeout(fetchTimeout);
      if (!trackDoc.exists) return null;

      final chunksSnap = await _db
          .collection(collection)
          .doc(cloudTrackId)
          .collection(chunksSubcollection)
          .orderBy('index')
          .get()
          .timeout(fetchTimeout);

      if (chunksSnap.docs.isEmpty) return null;

      final buffer = BytesBuilder(copy: false);
      for (final chunkDoc in chunksSnap.docs) {
        final data = chunkDoc.data()['data'] as String? ?? '';
        if (data.isEmpty) continue;
        buffer.add(base64Decode(data));
      }

      final dir = Directory(outPath).parent;
      if (!await dir.exists()) await dir.create(recursive: true);
      await File(outPath).writeAsBytes(buffer.toBytes(), flush: true);
      return outPath;
    } catch (e, st) {
      developer.log('⚠️ ensureTrackCached failed',
          name: 'SharedLibrary', error: e, stackTrace: st);
      return null;
    }
  }

  Future<void> deleteSharedTrack(String cloudTrackId, String? _) async {
    final chunks = await _db
        .collection(collection)
        .doc(cloudTrackId)
        .collection(chunksSubcollection)
        .get();
    final batch = _db.batch();
    for (final c in chunks.docs) {
      batch.delete(c.reference);
    }
    batch.delete(_db.collection(collection).doc(cloudTrackId));
    await batch.commit();

    try {
      final path = await cachedFilePath(cloudTrackId);
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }

  Future<String> cachedFilePath(String cloudTrackId) async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/shared_library/$cloudTrackId.mp3';
  }
}
