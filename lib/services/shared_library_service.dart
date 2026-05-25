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

  /// Raw bytes per chunk (keeps each Firestore doc under 1 MB limit).
  static const int chunkByteSize = 700000;

  /// ~15 MB max per upload on free tier.
  static const int maxFileBytes = 15 * 1024 * 1024;

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

  /// Upload audio + metadata (admin only — Firestore rules).
  Future<void> uploadSnippet({
    required String reciterName,
    required String trackTitle,
    required String localFilePath,
    required String uploadedByUid,
    required String uploadedByName,
  }) async {
    final file = File(localFilePath);
    if (!await file.exists()) {
      throw Exception('الملف غير موجود');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > maxFileBytes) {
      throw Exception(
        'الملف كبير جداً (الحد ${maxFileBytes ~/ (1024 * 1024)} ميجا). استخدم ملفاً أصغر.',
      );
    }

    final trackId = _uuid.v4();
    final reciterId = reciterIdFor(reciterName);
    final totalChunks = (bytes.length / chunkByteSize).ceil();

    final trackRef = _db.collection(collection).doc(trackId);
    await trackRef.set({
      'reciterId': reciterId,
      'reciterNameAr': reciterName.trim(),
      'title': trackTitle.trim(),
      'uploadedBy': uploadedByUid,
      'uploadedByName': uploadedByName,
      'createdAt': FieldValue.serverTimestamp(),
      'totalChunks': totalChunks,
      'fileSize': bytes.length,
      'encoding': 'base64_chunks',
    });

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkByteSize;
      final end = (start + chunkByteSize < bytes.length)
          ? start + chunkByteSize
          : bytes.length;
      final slice = bytes.sublist(start, end);
      await trackRef.collection(chunksSubcollection).doc('$i').set({
        'index': i,
        'data': base64Encode(slice),
      });
    }

    developer.log(
      '☁️ Shared snippet uploaded (Firestore chunks): $trackId ($totalChunks chunks)',
      name: 'SharedLibrary',
    );
  }

  /// Fetch all shared snippets grouped as [Reciter]s (metadata only).
  Future<List<Reciter>> fetchSharedReciters() async {
    try {
      final snap = await _db.collection(collection).get();

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
          remoteUrl: '',
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
      final trackDoc =
          await _db.collection(collection).doc(cloudTrackId).get();
      if (!trackDoc.exists) return null;

      final chunksSnap = await _db
          .collection(collection)
          .doc(cloudTrackId)
          .collection(chunksSubcollection)
          .orderBy('index')
          .get();

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
