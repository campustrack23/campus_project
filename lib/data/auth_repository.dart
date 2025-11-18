// lib/data/auth_repository.dart
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:uuid/uuid.dart';
import '../core/models/user.dart';
import '../core/models/role.dart';

class AuthRepository {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Collection reference for user profiles
  CollectionReference<UserAccount> get _usersRef =>
      _db.collection('users').withConverter<UserAccount>(
        fromFirestore: (snapshot, _) => UserAccount.fromMap(snapshot.data()!),
        toFirestore: (user, _) => user.toMap(),
      );

  // Use the built-in Firebase auth state stream
  Stream<UserAccount?> authStateChanges() {
    return _auth.authStateChanges().asyncMap((firebaseUser) async {
      if (firebaseUser == null) {
        return null;
      }
      // Fetch our custom user profile from Firestore
      final userDoc = await _usersRef.doc(firebaseUser.uid).get();
      return userDoc.data();
    });
  }

  Future<UserAccount?> currentUser() async {
    final firebaseUser = _auth.currentUser;
    if (firebaseUser == null) {
      return null;
    }
    final userDoc = await _usersRef.doc(firebaseUser.uid).get();
    return userDoc.data();
  }

  Future<UserAccount?> loginWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(email: email, password: password);
    if (cred.user == null) return null;

    final userDoc = await _usersRef.doc(cred.user!.uid).get();
    final user = userDoc.data();

    if (user == null || !user.isActive) {
      await _auth.signOut(); // Log out if profile doesn't exist or is inactive
      throw Exception('User account not found or is inactive.');
    }
    return user;
  }

  // Phone login is complex and requires a full UI flow.
  // For now, we are focusing on email/password. Phone can be a placeholder.
  Future<UserAccount?> loginWithPhone(String phone, String password) async {
    // This is a placeholder. Real phone auth needs a UI for OTP.
    // We will find the user by phone number from the database and sign them in via custom token or email.
    // For simplicity, we are only implementing full email login.
    final snapshot = await _usersRef.where('phone', isEqualTo: phone).limit(1).get();
    if (snapshot.docs.isEmpty) throw Exception('Invalid credentials');

    final user = snapshot.docs.first.data();
    if (user.email == null || user.email!.isEmpty) {
      throw Exception('This phone number is not linked to an email account for login.');
    }

    // Now try to login with their email
    return loginWithEmail(user.email!, password);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  // --- Password Reset using Firebase ---
  Future<void> requestPasswordReset(String email) async {
    await _auth.sendPasswordResetEmail(email: email);
  }

  // --- User Management (Admin) ---
  Future<List<UserAccount>> allUsers() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<UserAccount>> allStudents() async {
    final snapshot = await _usersRef.where('role', isEqualTo: 'student').get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<List<UserAccount>> studentsInSection(String section) async {
    final snapshot = await _usersRef
        .where('role', isEqualTo: 'student')
        .where('section', isEqualTo: section.toUpperCase())
        .where('isActive', isEqualTo: true)
        .get();
    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<void> updateUser(UserAccount updated) async {
    await _usersRef.doc(updated.id).set(updated, SetOptions(merge: true));
  }

  Future<void> setActive(String userId, bool isActive) async {
    await _usersRef.doc(userId).update({'isActive': isActive});
  }

  // Admin forces a password reset. This needs a Cloud Function in a real app.
  // The client SDK cannot change another user's password.
  // For this project, we'll just notify the user to reset it.
  Future<void> resetPasswordForced(String userId, String newPassword) async {
    final userDoc = await _usersRef.doc(userId).get();
    final user = userDoc.data();
    if(user?.email != null) {
      await requestPasswordReset(user!.email!);
    } else {
      throw Exception('User does not have an email to send a reset link.');
    }
  }

  Future<UserAccount> createUser({
    required UserRole role,
    required String name,
    required String email, // Email is now required
    required String phone,
    required String password,
    String? collegeRollNo,
    String? examRollNo,
    String? section,
    int? year,
  }) async {
    // Step 1: Create user in Firebase Auth
    final fb_auth.UserCredential cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
    final firebaseUser = cred.user;
    if (firebaseUser == null) {
      throw Exception('Failed to create user in Firebase Auth.');
    }

    // Step 2: Create user profile document in Firestore
    final user = UserAccount(
      id: firebaseUser.uid, // Use the UID from Firebase Auth
      role: role,
      name: name,
      email: email,
      phone: phone,
      collegeRollNo: collegeRollNo,
      examRollNo: examRollNo,
      section: section,
      year: year,
      passwordHash: '', // Not needed when using Firebase Auth
      createdAt: DateTime.now(),
    );

    await _usersRef.doc(user.id).set(user);
    return user;
  }
}

// Keep this extension, it's useful
extension IterableX<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final e in this) {
      if (test(e)) return e;
    }
    return null;
  }
  T? get firstOrNull => isEmpty ? null : first;
}