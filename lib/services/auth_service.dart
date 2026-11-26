import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

class AppUser {
  final String uid;
  final String name;
  final String email;
  const AppUser({required this.uid, required this.name, required this.email});
  String get firstName => name.trim().isEmpty ? 'there' : name.trim().split(' ').first;
}

abstract class AuthService {
  ValueListenable<AppUser?> get user;
  bool get isDemo;
  Future<void> signUp(String name, String email, String password);
  Future<void> signIn(String email, String password);
  Future<void> signInWithGoogle();
  Future<void> resetPassword(String email);
  Future<void> signOut();
  Future<String?> idToken();
}

/// Firebase Authentication (free Spark plan): email/password and Google.
class FirebaseAuthService implements AuthService {
  final _auth = FirebaseAuth.instance;
  final _user = ValueNotifier<AppUser?>(null);
  FirebaseAuthService() {
    _auth.authStateChanges().listen((u) => _user.value = u == null ? null : AppUser(uid: u.uid, name: u.displayName ?? '', email: u.email ?? ''));
  }
  @override
  ValueListenable<AppUser?> get user => _user;
  @override
  bool get isDemo => false;

  @override
  Future<void> signUp(String name, String email, String password) async {
    final c = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    await c.user?.updateDisplayName(name);
    await c.user?.reload();
    final u = _auth.currentUser;
    if (u != null) _user.value = AppUser(uid: u.uid, name: name, email: u.email ?? email);
  }

  @override
  Future<void> signIn(String email, String password) => _auth.signInWithEmailAndPassword(email: email, password: password);

  @override
  Future<void> signInWithGoogle() async {
    final provider = GoogleAuthProvider();
    if (kIsWeb) {
      await _auth.signInWithPopup(provider);
    } else {
      await _auth.signInWithProvider(provider);
    }
  }

  @override
  Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email);
  @override
  Future<void> signOut() => _auth.signOut();
  @override
  Future<String?> idToken() async => _auth.currentUser?.getIdToken();
}

/// Demo mode: an on-device account so the app is usable before Firebase is set up.
class LocalAuthService implements AuthService {
  static const _k = 'potfolio_demo_user';
  final _user = ValueNotifier<AppUser?>(null);
  LocalAuthService() {
    _restore();
  }
  Future<void> _restore() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_k);
    if (raw != null) {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      _user.value = AppUser(uid: j['uid'] as String, name: j['name'] as String, email: j['email'] as String);
    }
  }

  Future<void> _save(AppUser u) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_k, jsonEncode({'uid': u.uid, 'name': u.name, 'email': u.email}));
    _user.value = u;
  }

  @override
  ValueListenable<AppUser?> get user => _user;
  @override
  bool get isDemo => true;
  @override
  Future<void> signUp(String name, String email, String password) => _save(AppUser(uid: const Uuid().v4(), name: name, email: email));
  @override
  Future<void> signIn(String email, String password) => _save(AppUser(uid: const Uuid().v4(), name: email.split('@').first, email: email));
  @override
  Future<void> signInWithGoogle() => _save(AppUser(uid: const Uuid().v4(), name: 'Demo user', email: 'demo@potfolio.app'));
  @override
  Future<void> resetPassword(String email) async {}
  @override
  Future<void> signOut() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_k);
    _user.value = null;
  }

  @override
  Future<String?> idToken() async => null;
}
