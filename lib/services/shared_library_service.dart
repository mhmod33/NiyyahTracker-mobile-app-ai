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

  static String _normalizeArabicName(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[\u064B-\u065F\u0670]'), '')
        .replaceAll(RegExp(r'[أإآ]'), 'ا')
        .replaceAll('ؤ', 'و')
        .replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Hides only the old bundled reciter id — NOT admin-added shared entries
  /// (those use ids like `shared_أحمد_فؤاد` in Firestore).
  static bool _isLegacyAhmedFouadReciter(String reciterId, String nameAr) {
    if (reciterId.startsWith('shared_')) return false;
    final normalizedId = _normalizeArabicName(reciterId.replaceAll('_', ' '));
    final normalizedName = _normalizeArabicName(nameAr);
    return reciterId == 'snippets_ahmed_fouad' ||
        normalizedId.contains('ahmed fouad') ||
        normalizedName.contains('ahmed fouad') ||
        (normalizedId.contains('احمد') && normalizedId.contains('فواد')) ||
        (normalizedName.contains('احمد') && normalizedName.contains('فواد'));
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
  Future<String> addLinkSnippet({
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
      final docRef = _db.collection(collection).doc(trackId);
      await docRef
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

      await _verifyOnServer(docRef);

      developer.log(
        '🔗 Shared link snippet added: $trackId ($url)',
        name: 'SharedLibrary',
      );

      return trackId;
    } catch (e, st) {
      developer.log('⚠️ addLinkSnippet failed',
          name: 'SharedLibrary', error: e, stackTrace: st);
      throw Exception(_firestoreErrorMessage(e));
    }
  }

  /// Update an existing link snippet (admin only — Firestore rules).
  Future<void> updateLinkSnippet({
    required String trackId,
    required String trackTitle,
    required String remoteUrl,
  }) async {
    final url = remoteUrl.trim();
    final uri = Uri.tryParse(url);
    if (url.isEmpty ||
        uri == null ||
        !(uri.isScheme('http') || uri.isScheme('https'))) {
      throw Exception('رابط غير صالح — يجب أن يبدأ بـ http أو https');
    }

    try {
      final docRef = _db.collection(collection).doc(trackId);
      await docRef
          .update({
            'title': trackTitle.trim(),
            'remoteUrl': url,
            'updatedAt': FieldValue.serverTimestamp(),
          })
          .timeout(metaWriteTimeout);

      await _verifyOnServer(docRef);

      developer.log(
        '✏️ Shared link snippet updated: $trackId ($url)',
        name: 'SharedLibrary',
      );
    } catch (e, st) {
      developer.log('⚠️ updateLinkSnippet failed',
          name: 'SharedLibrary', error: e, stackTrace: st);
      throw Exception(_firestoreErrorMessage(e));
    }
  }

  /// Confirms the write reached Firestore (not just the local offline cache).
  Future<void> _verifyOnServer(DocumentReference<Map<String, dynamic>> docRef) async {
    final snap = await docRef
        .get(const GetOptions(source: Source.server))
        .timeout(metaWriteTimeout);
    if (!snap.exists) {
      throw Exception(
        'فشل الحفظ على السحابة — تأكد أن لديك صلاحية الرفع وأن قواعد Firestore منشورة',
      );
    }
  }

  /// Fetch all shared snippets grouped as [Reciter]s (metadata only).
  Future<List<Reciter>> fetchSharedReciters({bool preferServer = true}) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      if (preferServer) {
        try {
          snap = await _db
              .collection(collection)
              .get(const GetOptions(source: Source.server))
              .timeout(fetchTimeout);
        } catch (_) {
          snap = await _db.collection(collection).get().timeout(fetchTimeout);
        }
      } else {
        snap = await _db.collection(collection).get().timeout(fetchTimeout);
      }

      final Map<String, List<SnippetTrack>> byReciter = {};
      final Map<String, String> names = {};
      final Map<String, String> descriptions = {};
      var skippedLegacy = 0;

      for (final doc in snap.docs) {
        final d = doc.data();
        final reciterId = d['reciterId'] as String? ?? 'shared_unknown';
        final nameAr = d['reciterNameAr'] as String? ?? 'مقتطفات بصائر';
        final title = d['title'] as String? ?? 'مقطع';

        if (_isLegacyAhmedFouadReciter(reciterId, nameAr)) {
          skippedLegacy++;
          continue;
        }

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

      final reciters = byReciter.entries
          .map((e) => Reciter(
                id: e.key,
                nameAr: names[e.key]!,
                nameEn: '',
                description: descriptions[e.key]!,
                type: ReciterType.snippets,
                snippetTracks: e.value,
              ))
          .toList();

      developer.log(
        '📚 fetchSharedReciters: ${snap.docs.length} docs → '
        '${reciters.length} reciters (skipped legacy: $skippedLegacy)',
        name: 'SharedLibrary',
      );

      return reciters;
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
