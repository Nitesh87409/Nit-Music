import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:hive/hive.dart';
import 'package:musify/main.dart' show audioHandler, logger;
import 'package:musify/screens/search_page.dart' show reloadSearchHistoryFromStorage;
import 'package:musify/services/common_services.dart'
    show reloadSongLibraryStateFromStorage;
import 'package:musify/services/playlists_manager.dart'
    show reloadPlaylistLibraryStateFromStorage;
import 'package:musify/services/router_service.dart';
import 'package:musify/services/sync_service.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '44667727867-v51gu4rb8pfpkiirus599or3he62n6jf.apps.googleusercontent.com',
  );

  final ValueNotifier<bool> isLoggedIn = ValueNotifier<bool>(false);
  final ValueNotifier<User?> currentUser = ValueNotifier<User?>(null);
  final ValueNotifier<String?> userIdentifier = ValueNotifier<String?>(null);

  StreamSubscription<User?>? _authSub;

  String? get activeUserId {
    final savedPhone = Hive.box('user').get('loggedInPhone') as String?;
    if (savedPhone != null && savedPhone.isNotEmpty) return savedPhone;
    return _auth.currentUser?.uid;
  }

  /// Call once at app startup (after Firebase.initializeApp).
  void init() {
    final savedPhone = Hive.box('user').get('loggedInPhone') as String?;
    if (savedPhone != null && savedPhone.isNotEmpty) {
      isLoggedIn.value = true;
      userIdentifier.value =
          Hive.box('user').get('loggedInPhoneDisplay') ?? savedPhone;
      unawaited(SyncService.instance.restoreFromCloud());
    }

    _authSub = _auth.authStateChanges().listen((user) {
      currentUser.value = user;
      if (user != null) {
        isLoggedIn.value = true;
        userIdentifier.value =
            user.displayName ?? user.phoneNumber ?? user.email;
      } else {
        final phone = Hive.box('user').get('loggedInPhone');
        if (phone == null) {
          isLoggedIn.value = false;
          userIdentifier.value = null;
        }
      }
      try {
        NavigationManager.refreshRouter();
      } catch (_) {}
    });
  }

  void dispose() {
    _authSub?.cancel();
  }

  User? get user => _auth.currentUser;

  /// Sign in with Phone number and OTP.
  /// If [otp] is '0000' or '000000', uses deterministic test auth.
  Future<bool> signInWithPhone({
    required String phoneNumber,
    required String otp,
    String? verificationId,
  }) async {
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.length < 10) return false;

    final formattedPhone = cleanPhone.length > 10
        ? '+$cleanPhone'
        : '+91$cleanPhone';

    // Testing OTP bypass (0000 or 000000)
    if (otp == '0000' || otp == '000000') {
      try {
        final userBox = Hive.box('user');
        await userBox.put('loggedInPhone', cleanPhone);
        await userBox.put('loggedInPhoneDisplay', formattedPhone);
        userIdentifier.value = formattedPhone;

        // Restore cloud data FIRST before setting isLoggedIn.value = true
        // so all liked songs, playlists, and history are in local memory
        // BEFORE router redirects away from LoginPage!
        try {
          final hasCloud = await SyncService.instance.hasCloudData();
          if (hasCloud) {
            await SyncService.instance.restoreFromCloud();
          } else {
            await SyncService.instance.initNewUser(cleanPhone, formattedPhone);
          }
        } catch (e, st) {
          logger.log(
            'Error restoring cloud data during phone sign-in',
            error: e,
            stackTrace: st,
          );
        }

        isLoggedIn.value = true;

        try {
          NavigationManager.refreshRouter();
        } catch (_) {}
        return true;
      } catch (e, st) {
        logger.log(
          'AuthService.signInWithPhone (test OTP) error',
          error: e,
          stackTrace: st,
        );
        return false;
      }
    }

    // Real Phone Auth verification
    if (verificationId != null && verificationId.isNotEmpty) {
      try {
        final credential = PhoneAuthProvider.credential(
          verificationId: verificationId,
          smsCode: otp,
        );
        final userCredential = await _auth.signInWithCredential(credential);
        if (userCredential.user != null) {
          final userBox = Hive.box('user');
          await userBox.put('loggedInPhone', cleanPhone);
          await userBox.put('loggedInPhoneDisplay', formattedPhone);
          userIdentifier.value = formattedPhone;
          isLoggedIn.value = true;
          try {
            NavigationManager.refreshRouter();
          } catch (_) {}
          return true;
        }
      } catch (e, st) {
        logger.log('AuthService.signInWithPhone error', error: e, stackTrace: st);
        return false;
      }
    }
    return false;
  }

  /// Send real SMS OTP to phone number if needed.
  Future<String?> sendPhoneOtp({
    required String phoneNumber,
    required Function(String verificationId) onCodeSent,
    required Function(String error) onError,
  }) async {
    try {
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
      final formattedPhone = cleanPhone.length > 10
          ? '+$cleanPhone'
          : '+91$cleanPhone';

      await _auth.verifyPhoneNumber(
        phoneNumber: formattedPhone,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          onError(e.message ?? 'Verification failed');
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
      return null;
    } catch (e) {
      onError(e.toString());
      return null;
    }
  }

  /// Sign in with Google 1-tap.
  Future<User?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // User cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e, st) {
      logger.log('AuthService.signInWithGoogle error', error: e, stackTrace: st);
      return null;
    }
  }

  /// Sign out from both Firebase and Google and clear all user session data.
  Future<void> signOut() async {
    try {
      SyncService.instance.stopSync();
      try {
        await audioHandler.stop();
      } catch (_) {}
      final userBox = Hive.box('user');
      await userBox.clear();
      userIdentifier.value = null;
      isLoggedIn.value = false;
      reloadSongLibraryStateFromStorage();
      reloadPlaylistLibraryStateFromStorage();
      reloadSearchHistoryFromStorage();
      await _googleSignIn.signOut();
      await _auth.signOut();
      try {
        NavigationManager.refreshRouter();
      } catch (_) {}
    } catch (e, st) {
      logger.log('AuthService.signOut error', error: e, stackTrace: st);
    }
  }
}
