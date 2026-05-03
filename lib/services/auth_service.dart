import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

enum UserRole { admin, user }

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final UserRole role;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
  });

  bool get isAdmin => role == UserRole.admin;

  factory AppUser.fromDoc(String uid, Map<String, dynamic> data) => AppUser(
    uid: uid,
    email: data['email'] ?? '',
    displayName: data['displayName'] ?? data['email']?.split('@').first ?? 'Utilizador',
    role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
  );
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AppUser? _appUser;
  AppUser? get appUser => _appUser;
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isAdmin => _appUser?.isAdmin ?? false;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Carregar perfil ────────────────────────────────────────────────────
  Future<void> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) { _appUser = null; return; }

    try {
      final doc = await _db.collection('users').doc(user.uid).get();
      if (doc.exists) {
        _appUser = AppUser.fromDoc(user.uid, doc.data()!);
      }
    } catch (e) {
      debugPrint('[AUTH] Erro ao carregar perfil: $e');
    }
    notifyListeners();
  }

  // ── Registo ────────────────────────────────────────────────────────────
  Future<String?> register(
      String email,
      String password,
      String displayName,
      String adminCode,
      ) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );

      final isAdminCode = adminCode.trim() == 'iot_2026';
      final role = isAdminCode ? 'admin' : 'user';
      final name = displayName.trim().isEmpty
          ? email.split('@').first
          : displayName.trim();

      await _db.collection('users').doc(cred.user!.uid).set({
        'email': email.trim(),
        'displayName': name,
        'role': role,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await loadUserProfile();

      await _saveAuthLog(
        uid: cred.user!.uid,
        userName: name,
        type: 'userRegister',
        message: '$name registou-se como ${isAdminCode ? "administrador" : "utilizador"}',
        role: role,
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    } catch (e) {
      return 'Erro ao guardar perfil. Tenta novamente.';
    }
  }

  // ── Login ──────────────────────────────────────────────────────────────
  Future<String?> login(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password.trim(),
      );
      await loadUserProfile();

      await _saveAuthLog(
        uid: _auth.currentUser!.uid,
        userName: _appUser?.displayName ?? email.split('@').first,
        type: 'userLogin',
        message: '${_appUser?.displayName ?? email.split('@').first} iniciou sessão',
        role: _appUser?.role.name ?? 'user',
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────
  Future<void> logout() async {
    if (_auth.currentUser != null && _appUser != null) {
      await _saveAuthLog(
        uid: _auth.currentUser!.uid,
        userName: _appUser!.displayName,
        type: 'userLogout',
        message: '${_appUser!.displayName} terminou sessão',
        role: _appUser!.role.name,
      );
    }

    await _auth.signOut();
    _appUser = null;
    notifyListeners();
  }

  // ── Auth Log ───────────────────────────────────────────────────────────
  Future<void> _saveAuthLog({
    required String uid,
    required String userName,
    required String type,
    required String message,
    required String role,
  }) async {
    try {
      await _db.collection('logs').add({
        'id': '${DateTime.now().millisecondsSinceEpoch}_auth',
        'type': type,
        'zoneId': '',
        'message': message,
        'userName': userName,
        'userRole': role,
        'category': 'auth',
        'timestamp': FieldValue.serverTimestamp(),
        'uid': uid,
      });
    } catch (e) {
      debugPrint('[AUTH] Erro ao guardar log: $e');
    }
  }

  // ── Erros ──────────────────────────────────────────────────────────────
  String _errorMessage(String code) {
    switch (code) {
      case 'email-already-in-use':  return 'Este email já está registado.';
      case 'invalid-email':         return 'Email inválido.';
      case 'weak-password':         return 'Password demasiado fraca (mínimo 6 caracteres).';
      case 'user-not-found':        return 'Utilizador não encontrado.';
      case 'wrong-password':        return 'Password incorreta.';
      case 'invalid-credential':    return 'Credenciais inválidas.';
      case 'too-many-requests':     return 'Demasiadas tentativas. Tenta mais tarde.';
      default:                      return 'Erro inesperado. Tenta novamente.';
    }
  }
}