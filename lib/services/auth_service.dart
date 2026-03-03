import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in_all_platforms/google_sign_in_all_platforms.dart'
    as win;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

class AppUser {
  final String id;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final bool isGoogleUser;

  AppUser({
    required this.id,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.isGoogleUser = false,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'email': email,
    'displayName': displayName,
    'photoUrl': photoUrl,
    'isGoogleUser': isGoogleUser,
  };

  factory AppUser.fromMap(Map<String, dynamic> map) => AppUser(
    id: map['id'],
    email: map['email'],
    displayName: map['displayName'],
    photoUrl: map['photoUrl'],
    isGoogleUser: map['isGoogleUser'] ?? false,
  );
}

class AuthService {
  // Ganti dengan Web Client ID asli dari google-services.json (Project 29543706582)
  static const String googleClientId =
      "29543706582-f9q6bsdcvpr0l90abdsi7jktvj7gdc06.apps.googleusercontent.com";

  // Samakan dengan googleClientId untuk kemudahan development
  static const String windowsClientId =
      "29543706582-f9q6bsdcvpr0l90abdsi7jktvj7gdc06.apps.googleusercontent.com";

  static const String _manualUsersKey = 'manual_users_db';
  static const String _currentUserKey = 'current_user_session';

  static AppUser? _user;
  static final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  // FIX: Inisialisasi GoogleSignIn Windows di luar fungsi untuk menghindari Assertion Error
  static final win.GoogleSignIn _winSignIn = win.GoogleSignIn(
    params: win.GoogleSignInParams(
      clientId: windowsClientId,
      scopes: ['email', 'https://www.googleapis.com/auth/calendar.events'],
    ),
  );

  // FIX: GoogleSignIn konvensional (Web/Mobile)
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    // Menggunakan clientId untuk Web dan serverClientId untuk Android (Fix Error 10)
    clientId: kIsWeb ? googleClientId : null,
    serverClientId: googleClientId,
    scopes: ['email', 'https://www.googleapis.com/auth/calendar.events'],
  );

  static bool get isGoogleSupported {
    if (kIsWeb) return true;
    try {
      return Platform.isAndroid || Platform.isIOS || Platform.isWindows;
    } catch (_) {
      return false;
    }
  }

  // ================= EMAIL / PASSWORD AUTH (MANUAL) =================

  static Future<AppUser?> registerWithEmail(
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_manualUsersKey);

    Map<String, String> users = {};
    if (usersJson != null) {
      users = Map<String, String>.from(jsonDecode(usersJson));
    }

    if (users.containsKey(email)) {
      throw Exception("Email sudah terdaftar.");
    }

    users[email] = password;
    await prefs.setString(_manualUsersKey, jsonEncode(users));

    return signInWithEmail(email, password);
  }

  static Future<AppUser?> signInWithEmail(String email, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final usersJson = prefs.getString(_manualUsersKey);

    if (usersJson == null) throw Exception("User tidak ditemukan.");

    final users = jsonDecode(usersJson) as Map<String, dynamic>;
    if (users[email] != password) {
      throw Exception("Email atau password salah.");
    }

    _user = AppUser(
      id: email,
      email: email,
      displayName: email.split('@')[0],
      isGoogleUser: false,
    );

    await prefs.setString(_currentUserKey, jsonEncode(_user!.toMap()));
    _authStateController.add(_user);
    return _user;
  }

  // ================= GOOGLE AUTH (MULTI PLATFORM) =================

  static Future<AppUser?> signIn() async {
    try {
      if (!isGoogleSupported) {
        throw UnsupportedError('Google Sign-In tidak didukung di platform ini');
      }

      if (kIsWeb || Platform.isAndroid || Platform.isIOS) {
        // Logika untuk Web & Mobile menggunakan GoogleSignIn standar
        final account = await _googleSignIn.signIn();
        if (account == null) return null;

        _user = AppUser(
          id: account.id,
          email: account.email,
          displayName: account.displayName,
          photoUrl: account.photoUrl,
          isGoogleUser: true,
        );
      } else if (Platform.isWindows) {
        // Logika untuk Windows menggunakan _winSignIn yang sudah diinisialisasi di atas
        final creds = await _winSignIn.signIn();
        if (creds == null) return null;

        _user = AppUser(
          id: creds.idToken ?? "win_user",
          email:
              "windows-user@example.com", // Plugin ini kadang tidak langsung memberi email user
          displayName: "Windows User",
          isGoogleUser: true,
        );
      }

      // Simpan session ke SharedPreferences
      if (_user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_currentUserKey, jsonEncode(_user!.toMap()));
        _authStateController.add(_user);
      }

      return _user;
    } catch (error) {
      debugPrint("Login Error: $error");
      rethrow;
    }
  }

  // ================= SIGN OUT =================

  static Future<void> signOut() async {
    try {
      if (_user?.isGoogleUser == true) {
        if (!kIsWeb && Platform.isWindows) {
          // Windows plugin session clearing
        } else {
          await _googleSignIn.signOut();
        }
      }
    } catch (e) {
      debugPrint("SignOut Error: $e");
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);

      _user = null;
      _authStateController.add(null);
    }
  }

  // ================= SESSION MANAGER =================

  static Future<void> checkInitialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_currentUserKey);

    if (userJson != null) {
      _user = AppUser.fromMap(jsonDecode(userJson));
      _authStateController.add(_user);
    }

    // Silent Sign-In untuk Google User
    if (_user == null && isGoogleSupported && (kIsWeb || !Platform.isWindows)) {
      try {
        final account = await _googleSignIn.signInSilently();
        if (account != null) {
          _user = AppUser(
            id: account.id,
            email: account.email,
            displayName: account.displayName,
            photoUrl: account.photoUrl,
            isGoogleUser: true,
          );
          await prefs.setString(_currentUserKey, jsonEncode(_user!.toMap()));
          _authStateController.add(_user);
        }
      } catch (e) {
        debugPrint("Silent Sign-In Error: $e");
      }
    }
  }

  static AppUser? get currentUser => _user;
  static Stream<AppUser?> get onAuthStateChanged => _authStateController.stream;
}
