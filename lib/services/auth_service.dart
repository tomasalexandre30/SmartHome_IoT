import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
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
    displayName: data['displayName'] ??
        data['email']?.split('@').first ??
        'Utilizador',
    role: data['role'] == 'admin' ? UserRole.admin : UserRole.user,
  );
}

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: FirebaseDatabase.instance.app,
    databaseURL:
    'https://smartspaceiot-default-rtdb.europe-west1.firebasedatabase.app',
  );

  AppUser? _appUser;
  AppUser? get appUser => _appUser;
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isAdmin => _appUser?.isAdmin ?? false;

  bool _accountDeleted = false;
  bool get accountDeleted => _accountDeleted;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Carregar perfil ────────────────────────────────────────────────────
  Future<void> loadUserProfile() async {
    final user = _auth.currentUser;
    if (user == null) {
      _appUser = null;
      return;
    }
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
        message:
        '$name registou-se como ${isAdminCode ? "administrador" : "utilizador"}',
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
        message:
        '${_appUser?.displayName ?? email.split('@').first} iniciou sessão',
        role: _appUser?.role.name ?? 'user',
      );

      return null;
    } on FirebaseAuthException catch (e) {
      return _errorMessage(e.code);
    }
  }

  // ── Logout ─────────────────────────────────────────────────────────────
  Future<void> logout() async {
    final uid = _auth.currentUser?.uid;
    final name = _appUser?.displayName;
    final role = _appUser?.role.name ?? 'user';

    if (uid != null && name != null) {
      await _saveAuthLog(
        uid: uid,
        userName: name,
        type: 'userLogout',
        message: '$name terminou sessão',
        role: role,
      );

      // ✅ Remove o utilizador de TODAS as zonas antes de fazer logout
      // (o clearZoneOnLogout do provider já trata da zona atual,
      //  mas esta chamada garante limpeza completa mesmo em casos edge)
      try {
        await _removeUserFromAllZones(uid);
      } catch (e) {
        debugPrint('[AUTH] Erro ao limpar zonas no logout: $e');
      }

      // Marca como offline no RTDB
      try {
        await _rtdb.ref('smartspace/users/$uid').update({
          'online': false,
          'lastSeen': ServerValue.timestamp,
          'currentZoneId': null,
        });
      } catch (e) {
        debugPrint('[AUTH] Erro ao marcar offline no logout: $e');
      }
    }

    await _auth.signOut();
    _accountDeleted = false;
    _appUser = null;
    notifyListeners();
  }

  /// Remove o uid de todas as zonas onde apareça em presentUsers.
  /// Lógica duplicada aqui (não depende do DatabaseService) para funcionar
  /// mesmo que o provider já tenha sido destruído.
  Future<void> _removeUserFromAllZones(String uid) async {
    final zonesSnap = await _rtdb.ref('smartspace/zones').get();
    if (!zonesSnap.exists) return;

    final zones = Map<String, dynamic>.from(zonesSnap.value as Map);
    for (final entry in zones.entries) {
      final zoneId = entry.key as String;
      final zoneData = Map<String, dynamic>.from(entry.value as Map);
      final presentUsers = zoneData['presentUsers'];

      if (presentUsers is Map && presentUsers.containsKey(uid)) {
        final remaining = Map.from(presentUsers)..remove(uid);
        final newCount = remaining.length;
        await _rtdb.ref('smartspace/zones/$zoneId').update({
          'presentUsers/$uid': null,
          'occupantCount': newCount,
          'status': newCount == 0 ? 'free' : 'occupied',
          'lastUpdated': ServerValue.timestamp,
        });
        debugPrint('[AUTH] Logout cleanup: $uid removido de $zoneId → $newCount');
      }
    }
  }

  // ── Apagar conta ───────────────────────────────────────────────────────
  Future<String?> deleteAccount({required String password}) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 'Utilizador não encontrado.';

      debugPrint('[AUTH] A apagar conta: ${user.uid}');

      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        debugPrint('[AUTH] Reautenticação bem sucedida');
      } on FirebaseAuthException catch (e) {
        if (e.code == 'wrong-password' || e.code == 'invalid-credential') {
          return 'Password incorreta. Tenta novamente.';
        }
        return _errorMessage(e.code);
      }

      // ✅ Limpa zonas antes de apagar a conta
      try {
        await _removeUserFromAllZones(user.uid);
      } catch (e) {
        debugPrint('[AUTH] Erro ao limpar zonas no deleteAccount: $e');
      }

      // Apaga preferências do Firestore
      try {
        final prefsSnap = await _db
            .collection('users')
            .doc(user.uid)
            .collection('preferences')
            .get();
        for (final doc in prefsSnap.docs) {
          await doc.reference.delete();
        }
        debugPrint('[AUTH] Preferências apagadas');
      } catch (e) {
        debugPrint('[AUTH] Erro ao apagar preferências: $e');
      }

      // Apaga perfil do Firestore
      try {
        await _db.collection('users').doc(user.uid).delete();
        debugPrint('[AUTH] Perfil Firestore apagado');
      } catch (e) {
        debugPrint('[AUTH] Erro ao apagar perfil: $e');
      }

      // Remove da Realtime Database
      try {
        await _rtdb.ref('smartspace/users/${user.uid}').remove();
        debugPrint('[AUTH] Realtime Database apagado');
      } catch (e) {
        debugPrint('[AUTH] Erro ao apagar RTDB: $e');
      }

      await user.delete();
      debugPrint('[AUTH] Conta Firebase Auth apagada');

      _accountDeleted = true;
      _appUser = null;
      notifyListeners();
      return null;
    } catch (e) {
      debugPrint('[AUTH] Erro geral ao apagar conta: $e');
      return 'Erro ao apagar conta. Tenta novamente.';
    }
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
      case 'email-already-in-use':
        return 'Este email já está registado.';
      case 'invalid-email':
        return 'Email inválido.';
      case 'weak-password':
        return 'Password demasiado fraca (mínimo 6 caracteres).';
      case 'user-not-found':
        return 'Utilizador não encontrado.';
      case 'wrong-password':
        return 'Password incorreta.';
      case 'invalid-credential':
        return 'Credenciais inválidas.';
      case 'too-many-requests':
        return 'Demasiadas tentativas. Tenta mais tarde.';
      default:
        return 'Erro inesperado. Tenta novamente.';
    }
  }
}