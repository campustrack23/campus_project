// lib/core/utils/firebase_error_parser.dart
// --- FIX: Corrected the import path ---
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseErrorParser {
  /// Translates a Firebase error code into a user-friendly message.
  static String getMessage(Object e) {
    // If it's not a Firebase error, just return the plain message
    if (e is! FirebaseAuthException) {
      return e.toString().replaceAll('Exception: ', '');
    }

    // Handle specific, common Firebase error codes
    switch (e.code) {
      case 'invalid-credential':
      case 'invalid-email':
      case 'wrong-password':
      case 'user-not-found':
        return 'Invalid email or password. Please try again.';
      case 'email-already-in-use':
        return 'An account with this email address already exists.';
      case 'weak-password':
        return 'The password is too weak. Please use at least 6 characters.';
      case 'network-request-failed':
        return 'A network error occurred. Please check your internet connection.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'An unexpected error occurred. Please try again.';
    }
  }
}