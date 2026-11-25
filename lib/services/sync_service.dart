import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show logger;
import 'package:musify/services/auth_service.dart';
import 'package:musify/services/common_services.dart';
import 'package:musify/services/playlists_manager.dart';
import 'package:musify/screens/search_page.dart' show reloadSearchHistoryFromStorage;

class SyncService {
  SyncService._();
  static final SyncService instance = SyncService._();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Timer? _debounceTimer;
  final Set<String> _pendingKeys = {};

  /// All Hive 'user' box keys that should be synced to Firestore.
  static const List<String> syncKeys = [
    'likedSongs',
    'recentlyPlayedSongs',
    'searchHistory',
    'playlists',
    'customPlaylists',
    'likedPlaylists',
    'playlistFolders',
    'pinnedPlaylistIds',
    'likedRadioStations',
  ];

  // ───────────────── Upload (Local → Cloud) ─────────────────

  /// Queue a key for syncing. Debounced — waits 2s after last call,
  /// but flushes immediately for critical user data (likedSongs, playlists).
  void queueSync(String key, dynamic value) {
    if (!AuthService.instance.isLoggedIn.value) return;
    if (!syncKeys.contains(key)) return;

    _pendingKeys.add(key);

    // Critical actions like likedSongs and playlists must sync immediately to Firestore!
    if (key == 'likedSongs' || key == 'playlists' || key == 'customPlaylists') {
      _debounceTimer?.cancel();
      unawaited(_flushPendingSync());
      return;
    }

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), _flushPendingSync);
  }

  Future<void> _flushPendingSync() async {
    final uid = AuthService.instance.activeUserId;
    if (uid == null || _pendingKeys.isEmpty) return;

    final keysToSync = Set<String>.from(_pendingKeys);
    _pendingKeys.clear();

    try {
      final userBox = Hive.box('user');
      final data = <String, dynamic>{};

      for (final key in keysToSync) {
        final value = userBox.get(key);
        if (value != null) {
          // Firestore needs serializable data — Hive Lists/Maps need casting
          data[key] = _toFirestoreValue(value);
        }
      }

      if (data.isNotEmpty) {
        data['lastSyncedAt'] = FieldValue.serverTimestamp();
        await _userDoc(uid).set(data, SetOptions(merge: true));
      }
    } catch (e, st) {
      logger.log('SyncService._flushPendingSync error', error: e, stackTrace: st);
      // Re-add failed keys so they retry on next change
      _pendingKeys.addAll(keysToSync);
    }
  }

  /// Force upload ALL syncable data to cloud right now.
  Future<void> uploadAll() async {
    final uid = AuthService.instance.activeUserId;
    if (uid == null) return;

    try {
      final userBox = Hive.box('user');
      final data = <String, dynamic>{};

      for (final key in syncKeys) {
        final value = userBox.get(key);
        if (value != null) {
          data[key] = _toFirestoreValue(value);
        }
      }

      if (data.isNotEmpty) {
        data['lastSyncedAt'] = FieldValue.serverTimestamp();
        await _userDoc(uid).set(data, SetOptions(merge: true));
      }
    } catch (e, st) {
      logger.log('SyncService.uploadAll error', error: e, stackTrace: st);
    }
  }

  // ───────────────── Download (Cloud → Local) ─────────────────

  /// Check if cloud data exists for the current user.
  Future<bool> hasCloudData() async {
    final uid = AuthService.instance.activeUserId;
    if (uid == null) return false;

    try {
      final doc = await _userDoc(uid).get();
      return doc.exists;
    } catch (e, st) {
      logger.log('SyncService.hasCloudData error', error: e, stackTrace: st);
      return false;
    }
  }

  /// Download cloud data and restore into local Hive (overwrites local state cleanly).
  /// Returns true on success.
  Future<bool> restoreFromCloud() async {
    final uid = AuthService.instance.activeUserId;
    if (uid == null) return false;

    try {
      final doc = await _userDoc(uid).get();
      if (!doc.exists) return false;

      final cloudData = doc.data()!;
      final userBox = Hive.box('user');

      for (final key in syncKeys) {
        if (!cloudData.containsKey(key)) {
          await userBox.delete(key);
          continue;
        }
        final cloudValue = _toHiveValue(cloudData[key]);
        if (cloudValue != null) {
          await userBox.put(key, cloudValue);
        } else {
          await userBox.delete(key);
        }
      }

      // Reload in-memory state from Hive
      reloadSongLibraryStateFromStorage();
      reloadPlaylistLibraryStateFromStorage();
      reloadSearchHistoryFromStorage();

      return true;
    } catch (e, st) {
      logger.log('SyncService.restoreFromCloud error', error: e, stackTrace: st);
      return false;
    }
  }

  /// Initialize a fresh cloud profile for a new user without uploading residual local data.
  Future<void> initNewUser(String uid, String formattedPhone) async {
    try {
      await _userDoc(uid).set({
        'phoneNumber': formattedPhone,
        'createdAt': FieldValue.serverTimestamp(),
        'lastSyncedAt': FieldValue.serverTimestamp(),
      });
      reloadSongLibraryStateFromStorage();
      reloadPlaylistLibraryStateFromStorage();
      reloadSearchHistoryFromStorage();
    } catch (e, st) {
      logger.log('SyncService.initNewUser error', error: e, stackTrace: st);
    }
  }

  /// Stop any pending sync timers.
  void stopSync() {
    _debounceTimer?.cancel();
    _pendingKeys.clear();
  }

  // ───────────────── Helpers ─────────────────

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) {
    return _firestore.collection('users').doc(uid);
  }

  /// Convert Firestore values (like Timestamp) back to Hive-safe types.
  dynamic _toHiveValue(dynamic value) {
    if (value is Timestamp) {
      return value.toDate();
    }
    if (value is List) {
      return value.map(_toHiveValue).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toHiveValue(v)));
    }
    return value;
  }

  /// Convert Hive value to Firestore-safe format.
  dynamic _toFirestoreValue(dynamic value) {
    if (value is List) {
      return value.map(_toFirestoreValue).toList();
    }
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), _toFirestoreValue(v)));
    }
    return value;
  }
}
