import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:convert';

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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'isGoogleUser': isGoogleUser,
    };
  }

  factory AppUser.fromMap(Map<String, dynamic> map) {
    return AppUser(
      id: map['id'],
      email: map['email'],
      displayName: map['displayName'],
      photoUrl: map['photoUrl'],
      isGoogleUser: map['isGoogleUser'] ?? false,
    );
  }
}

class AuthService {
  static const String googleClientId =
      "809885834954-j6u776unsh6e6re2g3p2v943k9b4o1v0.apps.googleusercontent.com";
  static const String _manualUsersKey = 'manual_users_db';
  static const String _currentUserKey = 'current_user_session';

  static AppUser? _user;
  static final StreamController<AppUser?> _authStateController =
      StreamController<AppUser?>.broadcast();

  static Future<void> _initialize() async {
    final googleSignIn = GoogleSignIn.instance;
    await googleSignIn.initialize(
      clientId: googleClientId.contains("YOUR_CLIENT_ID")
          ? null
          : googleClientId,
    );
  }

  // --- NEW: Email/Password Auth ---

  static Future<AppUser?> registerWithEmail(
    String email,
    String password,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersJson = prefs.getString(_manualUsersKey);
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
    final String? usersJson = prefs.getString(_manualUsersKey);
    if (usersJson == null) throw Exception("User tidak ditemukan.");

    final Map<String, dynamic> users = jsonDecode(usersJson);
    if (users[email] != password) throw Exception("Email atau password salah.");

    final user = AppUser(
      id: email,
      email: email,
      displayName: email.split('@')[0],
      isGoogleUser: false,
    );

    _user = user;
    await prefs.setString(_currentUserKey, jsonEncode(user.toMap()));
    _authStateController.add(_user);
    return _user;
  }

  // --- Existing: Google Auth ---

  static Future<AppUser?> signIn() async {
    try {
      final googleSignIn = GoogleSignIn.instance;
      await _initialize();

      GoogleSignInAccount? account;

      if (kIsWeb) {
        // Pada web, coba gunakan signIn() melalui dynamic sebagai alternatif jika authenticate() gagal
        try {
          account = await (googleSignIn as dynamic).signIn();
        } catch (_) {
          account = await googleSignIn.authenticate();
        }
      } else {
        // Pada Android/iOS, gunakan authenticate() yang stabil
        account = await googleSignIn.authenticate();
      }

      if (account == null) return null;

      _user = AppUser(
        id: account.id,
        email: account.email,
        displayName: account.displayName,
        photoUrl: account.photoUrl,
        isGoogleUser: true,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_currentUserKey, jsonEncode(_user!.toMap()));
      _authStateController.add(_user);
      return _user;
    } catch (error) {
      print("Login Error: $error");
      rethrow;
    }
  }

  static Future<void> signOut() async {
    try {
      if (_user?.isGoogleUser == true) {
        final googleSignIn = GoogleSignIn.instance;
        if (kIsWeb) {
          await (googleSignIn as dynamic).signOut();
        } else {
          await googleSignIn.signOut();
        }
      }
    } catch (e) {
      print("Error signing out: $e");
    } finally {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_currentUserKey);

      _user = null;
      _authStateController.add(null);
    }
  }

  static Future<void> checkInitialAuth() async {
    final prefs = await SharedPreferences.getInstance();
    final String? userJson = prefs.getString(_currentUserKey);
    if (userJson != null) {
      _user = AppUser.fromMap(jsonDecode(userJson));
      _authStateController.add(_user);
    }
  }

  static AppUser? get currentUser => _user;

  static Stream<AppUser?> get onAuthStateChanged => _authStateController.stream;
}
