// lib/data/auth_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../core/models/user.dart';
import '../core/models/role.dart';
import '../core/services/local_storage.dart';
import '../core/utils/firebase_error_parser.dart';

class AuthRepository {
  final LocalStorage _storage;
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  AuthRepository(this._storage);

  // ---------------------------------------------------------------------------
  // FIRESTORE USERS COLLECTION (WITH SAFE ID MAPPING)
  // ---------------------------------------------------------------------------

  CollectionReference<UserAccount> get _usersRef =>
      _db.collection('users').withConverter<UserAccount>(
        fromFirestore: (snap, _) =>
            UserAccount.fromMap(snap.id, snap.data()!),
        toFirestore: (user, _) => user.toMap(),
      );

  // ---------------------------------------------------------------------------
  // AUTH STATE
  // ---------------------------------------------------------------------------

  Stream<UserAccount?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        await _storage.clearSession();
        return null;
      }
      try {
        final doc = await _usersRef.doc(firebaseUser.uid).get();
        if (!doc.exists) {
          await _auth.signOut();
          return null;
        }
        final user = doc.data();
        if (user != null && !user.isActive) {
          await logout();
          return null;
        }
        return user;
      } catch (e) {
        debugPrint('Auth State Error: ${FirebaseErrorParser.getMessage(e)}');
        return null;
      }
    });
  }

  Future<UserAccount?> currentUser() async {
    final u = _auth.currentUser;
    if (u == null) return null;
    final doc = await _usersRef.doc(u.uid).get();
    return doc.data();
  }

  // ---------------------------------------------------------------------------
  // LOGIN / LOGOUT
  // ---------------------------------------------------------------------------

  Future<UserAccount> loginWithEmail(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final doc = await _usersRef.doc(cred.user!.uid).get();
      if (!doc.exists) {
        await _auth.signOut();
        throw Exception('User record not found in database. Contact admin.');
      }
      final user = doc.data()!;
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
      final snapshot = await _usersRef
          .where('phone', isEqualTo: phone)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception('No account found with this phone number.');
      }

      final user = snapshot.docs.first.data();

      if (user.email == null || user.email!.isEmpty) {
        throw Exception('This account has no email linked.');
      }

      return loginWithEmail(user.email!, password);
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> logout() async {
    try {
      await _storage.clearSession();
      await _auth.signOut();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // PASSWORD RESET
  // ---------------------------------------------------------------------------

  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> triggerPasswordResetForUser(String userId) async {
    final doc = await _usersRef.doc(userId).get();
    final user = doc.data();

    if (user?.email != null) {
      await requestPasswordReset(user!.email!);
    } else {
      throw Exception('User does not have an email address.');
    }
  }

  // ---------------------------------------------------------------------------
  // USER CREATION (ADMIN)
  // ---------------------------------------------------------------------------

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
      // Create user in a temporary Firebase App instance so it doesn't
      // log out the current Admin user
      tempApp = await Firebase.initializeApp(
        name: 'tempUserCreation',
        options: Firebase.app().options,
      );

      final tempAuth = fb_auth.FirebaseAuth.instanceFor(app: tempApp);

      final cred = await tempAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

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

  // ---------------------------------------------------------------------------
  // USER UPDATE & STATUS
  // ---------------------------------------------------------------------------

  Future<void> updateUser(UserAccount user) async {
    try {
      final currentUserRecord = await currentUser();
      if (currentUserRecord == null) throw Exception('Not logged in.');

      // SECURITY FIX: Allow update if user is Admin OR if they are updating their own profile
      if (!currentUserRecord.role.isAdmin && currentUserRecord.id != user.id) {
        throw Exception('Insufficient permissions to modify this user.');
      }

      await _usersRef.doc(user.id).set(user, SetOptions(merge: true));
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> setActive(String userId, bool isActive) async {
    try {
      final currentUserRecord = await currentUser();
      if (currentUserRecord == null || !currentUserRecord.role.isAdmin) {
        throw Exception('Insufficient permissions.');
      }
      await _usersRef.doc(userId).update({'isActive': isActive});
    } catch (e) {
      throw Exception('Failed to update status: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // QUERIES
  // ---------------------------------------------------------------------------

  // SECURITY FIX: Limit queries to prevent massive PII dumps and read spikes.
  Future<List<UserAccount>> allUsers({int limit = 150}) async {
    try {
      final snapshot = await _usersRef
          .orderBy('name')
          .limit(limit)
          .get();
      return snapshot.docs.map((e) => e.data()).toList();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<List<UserAccount>> allStudents({int limit = 200}) async {
    try {
      final snapshot = await _usersRef
          .where('role', isEqualTo: UserRole.student.key)
          .orderBy('name')
          .limit(limit)
          .get();
      return snapshot.docs.map((e) => e.data()).toList();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<List<UserAccount>> studentsInSection(String section) async {
    try {
      final snapshot = await _usersRef
          .where('role', isEqualTo: UserRole.student.key)
          .where('section', isEqualTo: section.toUpperCase())
          .where('isActive', isEqualTo: true)
          .orderBy('collegeRollNo')
          .limit(150)
          .get();
      return snapshot.docs.map((e) => e.data()).toList();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  // ---------------------------------------------------------------------------
  // ACCOUNT DELETION
  // ---------------------------------------------------------------------------

  Future<void> deleteCurrentUserAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;

    try {
      await _usersRef.doc(user.uid).delete();
      await user.delete();
      await _storage.clearSession();
    } on fb_auth.FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        throw Exception('Please log out and log in again to delete your account.');
      }
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> deleteUserFirestoreOnly(String userId) async {
    try {
      final currentUserRecord = await currentUser();
      if (currentUserRecord == null || !currentUserRecord.role.isAdmin) {
        throw Exception('Insufficient permissions to delete users.');
      }
      await _usersRef.doc(userId).delete();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  Future<void> deleteAccount(String userId) async {
    try {
      final currentUserRecord = await currentUser();
      if (currentUserRecord == null) throw Exception('Not logged in');

      if (!currentUserRecord.role.isAdmin && currentUserRecord.id != userId) {
        throw Exception('Insufficient permissions to delete this account.');
      }
      await _usersRef.doc(userId).delete();
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }
}