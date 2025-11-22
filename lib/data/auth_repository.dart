// lib/data/auth_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import '../core/models/user.dart';
import '../core/models/role.dart';
import '../core/services/local_storage.dart';
import '../core/utils/firebase_error_parser.dart';

class AuthRepository {
  final LocalStorage _storage;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthRepository(this._storage);

  CollectionReference<UserAccount> get _usersRef =>
      _db.collection('users').withConverter<UserAccount>(
        fromFirestore: (snap, _) => UserAccount.fromMap(snap.data()!),
        toFirestore: (user, _) => user.toMap(),
      );

  // --- EXISTING METHODS ---

  Stream<UserAccount?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        final doc = await _usersRef.doc(firebaseUser.uid).get();
        final user = doc.data();
        if (user != null && !user.isActive) {
          await logout();
          return null;
        }
        return user;
      } catch (_) {
        return null;
      }
    });
  }

  Future<UserAccount?> currentUser() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) return null;
    final doc = await _usersRef.doc(fbUser.uid).get();
    return doc.data();
  }

  Future<UserAccount?> loginWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
      if (cred.user == null) throw Exception('Login failed');

      final doc = await _usersRef.doc(cred.user!.uid).get();
      final user = doc.data();

      if (user == null) {
        await _auth.signOut();
        throw Exception('User profile not found.');
      }

      if (!user.isActive) {
        await _auth.signOut();
        throw fb_auth.FirebaseAuthException(code: 'user-disabled');
      }

      return user;
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<UserAccount?> loginWithPhone(String phone, String password) async {
    try {
      final snapshot = await _usersRef.where('phone', isEqualTo: phone).limit(1).get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No account found with this phone number.');
      }

      final user = snapshot.docs.first.data();
      if (user.email == null || user.email!.isEmpty) {
        throw Exception('This account does not have an email linked for login.');
      }

      return loginWithEmail(user.email!, password);
    } catch (e) {
      if (e.toString().contains('No account')) rethrow;
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> logout() async {
    await _storage.clearSession();
    await _auth.signOut();
  }

  // --- NEW: DELETE ACCOUNT (Required for App Stores) ---
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      // 1. Delete Firestore Profile
      await _usersRef.doc(user.uid).delete();

      // 2. Delete Auth Account
      // Note: This might fail if the user hasn't logged in recently (requires re-auth).
      // For a production app, you'd handle the 'requires-recent-login' error here.
      await user.delete();

      await _storage.clearSession();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> createUser({
    required UserRole role,
    required String name,
    required String email,
    required String phone,
    required String password,
    String? collegeRollNo,
    String? examRollNo,
    String? section,
    int? year,
    List<String> qualifications = const [],
  }) async {
    FirebaseApp? tempApp;
    try {
      tempApp = await Firebase.initializeApp(
        name: 'tempCreationApp',
        options: Firebase.app().options,
      );

      final tempAuth = fb_auth.FirebaseAuth.instanceFor(app: tempApp);

      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      if (cred.user == null) throw Exception('Auth creation failed');

      final newUser = UserAccount(
        id: cred.user!.uid,
        role: role,
        name: name,
        email: email,
        phone: phone,
        collegeRollNo: collegeRollNo,
        examRollNo: examRollNo,
        section: section,
        year: year,
        passwordHash: 'managed_by_firebase',
        isActive: true,
        createdAt: DateTime.now(),
        qualifications: qualifications,
      );

      await _usersRef.doc(newUser.id).set(newUser);
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    } finally {
      await tempApp?.delete();
    }
  }

  Future<List<UserAccount>> allUsers() async {
    final snapshot = await _usersRef.orderBy('name').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<UserAccount>> studentsInSection(String section) async {
    final snapshot = await _usersRef
        .where('role', isEqualTo: 'student')
        .where('section', isEqualTo: section.toUpperCase())
        .where('isActive', isEqualTo: true)
        .orderBy('collegeRollNo')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> updateUser(UserAccount updated) async {
    try {
      await _usersRef.doc(updated.id).set(updated, SetOptions(merge: true));
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  Future<void> triggerPasswordResetForUser(String userId) async {
    final doc = await _usersRef.doc(userId).get();
    final user = doc.data();
    if (user != null && user.email != null) {
      await requestPasswordReset(user.email!);
    } else {
      throw Exception('User does not have an email address.');
    }
  }

  Future<List<UserAccount>> allStudents() async {
    final snapshot = await _usersRef
        .where('role', isEqualTo: 'student')
        .orderBy('name')
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> setActive(String userId, bool isActive) async {
    await _usersRef.doc(userId).update({
      'isActive': isActive,
    });
  }
}

extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
  T? get firstOrNull => isEmpty ? null : first;
}