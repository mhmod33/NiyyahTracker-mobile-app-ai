import 'dart:convert';
import 'dart:developer' as developer;
import 'package:hive_flutter/hive_flutter.dart';
import '../models/study_track_model.dart';

class StudyTrackService {
  static final StudyTrackService _instance = StudyTrackService._internal();
  factory StudyTrackService() => _instance;
  StudyTrackService._internal();

  static const _boxName = 'study_tracking';
  static const _keyPrefix = 'playlist_';

  Box? _box;

  Future<void> init() async {
    try {
      _box = Hive.isBoxOpen(_boxName)
          ? Hive.box(_boxName)
          : await Hive.openBox(_boxName);
      developer.log('✅ StudyTrackService initialized', name: 'StudyTrackService');
    } catch (e) {
      developer.log('❌ StudyTrackService init error: $e', name: 'StudyTrackService');
    }
  }

  Box get _safeBox {
    if (_box == null || !_box!.isOpen) {
      throw Exception('StudyTrackService not initialized — call init() first');
    }
    return _box!;
  }

  // ── Read ─────────────────────────────────────────────────────────────────

  List<StudyPlaylist> getAllPlaylists() {
    try {
      return _safeBox.keys
          .cast<String>()
          .where((k) => k.startsWith(_keyPrefix))
          .map((k) {
            final raw = _safeBox.get(k);
            if (raw == null) return null;
            try {
              return StudyPlaylist.fromJson(
                  Map<String, dynamic>.from(jsonDecode(raw as String)));
            } catch (_) {
              return null;
            }
          })
          .whereType<StudyPlaylist>()
          .toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    } catch (e) {
      developer.log('❌ getAllPlaylists error: $e', name: 'StudyTrackService');
      return [];
    }
  }

  StudyPlaylist? getPlaylist(String id) {
    try {
      final raw = _safeBox.get('$_keyPrefix$id');
      if (raw == null) return null;
      return StudyPlaylist.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw as String)));
    } catch (e) {
      developer.log('❌ getPlaylist error: $e', name: 'StudyTrackService');
      return null;
    }
  }

  // ── Write ────────────────────────────────────────────────────────────────

  Future<void> savePlaylist(StudyPlaylist playlist) async {
    try {
      await _safeBox.put('$_keyPrefix${playlist.id}', jsonEncode(playlist.toJson()));
      await _safeBox.flush();
    } catch (e) {
      developer.log('❌ savePlaylist error: $e', name: 'StudyTrackService');
    }
  }

  Future<void> deletePlaylist(String id) async {
    try {
      await _safeBox.delete('$_keyPrefix$id');
      await _safeBox.flush();
    } catch (e) {
      developer.log('❌ deletePlaylist error: $e', name: 'StudyTrackService');
    }
  }

  // ── Episode mutations ────────────────────────────────────────────────────

  Future<void> toggleItemWatched(String playlistId, String itemId) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return;
    final updatedItems = playlist.items.map((item) {
      return item.id == itemId
          ? item.copyWith(isWatched: !item.isWatched)
          : item;
    }).toList();
    await savePlaylist(playlist.copyWith(items: updatedItems));
  }

  Future<void> addItem(String playlistId, StudyItem item) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return;
    await savePlaylist(playlist.copyWith(items: [...playlist.items, item]));
  }

  Future<void> updateItem(String playlistId, StudyItem updatedItem) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return;
    final updatedItems = playlist.items
        .map((i) => i.id == updatedItem.id ? updatedItem : i)
        .toList();
    await savePlaylist(playlist.copyWith(items: updatedItems));
  }

  Future<void> deleteItem(String playlistId, String itemId) async {
    final playlist = getPlaylist(playlistId);
    if (playlist == null) return;
    final updatedItems =
        playlist.items.where((i) => i.id != itemId).toList();
    await savePlaylist(playlist.copyWith(items: updatedItems));
  }

  // ── Stats ────────────────────────────────────────────────────────────────

  int getTotalWatchedEpisodes() {
    return getAllPlaylists()
        .fold(0, (sum, p) => sum + p.watchedCount);
  }

  int getTotalEpisodes() {
    return getAllPlaylists()
        .fold(0, (sum, p) => sum + p.totalCount);
  }

  int getCompletedPlaylistsCount() {
    return getAllPlaylists().where((p) => p.isCompleted).length;
  }
}
