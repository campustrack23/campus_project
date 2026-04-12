// lib/data/auth_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
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

  CollectionReference<UserAccount> get _usersRef =>
      _db.collection('users').withConverter<UserAccount>(
        fromFirestore: (snap, _) =>
            UserAccount.fromMap(snap.id, snap.data()!),
        toFirestore: (user, _) => user.toMap(),
      );

  Stream<UserAccount?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) return null;
      try {
        final doc = await _usersRef.doc(firebaseUser.uid).get();
        if (doc.exists) {
          final user = doc.data();
          if (user != null) {
            await _storage.writeString('session_user_id', user.id);
            return user;
          }
        }
      } catch (e) {
        debugPrint('Error fetching user document: $e');
      }
      return null;
    });
  }

  Future<UserAccount?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) return null;

    try {
      final doc = await _usersRef.doc(firebaseUser.uid).get();
      return doc.data();
    } catch (e) {
      return null;
    }
  }

  // PERFORMANCE FIX: Prevent O(N) memory/read exhaustion
  // Implemented safety limits and sorting constraints
  Future<List<UserAccount>> allUsers({int limit = 1000}) async {
    final snapshot = await _usersRef.orderBy('name').limit(limit).get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<UserAccount>> allStudents({int limit = 1000}) async {
    final snapshot = await _usersRef
        .where('role', isEqualTo: UserRole.student.key)
        .limit(limit)
        .get();

    final students = snapshot.docs.map((doc) => doc.data()).toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  Future<List<UserAccount>> studentsInSection(String section, {int limit = 200}) async {
    final snapshot = await _usersRef
        .where('role', isEqualTo: UserRole.student.key)
        .where('section', isEqualTo: section)
        .limit(limit)
        .get();

    final students = snapshot.docs.map((doc) => doc.data()).toList();
    students.sort((a, b) => a.name.compareTo(b.name));
    return students;
  }

  Future<void> loginWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
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

  Future<void> updateUser(UserAccount user) async {
    try {
      await _usersRef.doc(user.id).set(user, SetOptions(merge: true));
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

  // FIXED: Added the missing password reset function
  Future<void> requestPasswordReset(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } catch (e) {
      throw Exception(FirebaseErrorParser.getMessage(e));
    }
  }

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