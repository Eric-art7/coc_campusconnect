import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

/// A readable, user-facing error (privacy rules, validation, etc.).
class AppException implements Exception {
  AppException(this.message);
  final String message;
  @override
  String toString() => message;
}

String friendlyError(Object e) {
  if (e is AppException) return e.message;
  if (e is FirebaseAuthException) {
    switch (e.code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'An account with this email already exists.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment and try again.';
      case 'network-request-failed':
        return 'No connection. Check your internet and try again.';
      default:
        return e.message ?? 'Account request failed.';
    }
  }
  if (e is FirebaseException) {
    if (e.code == 'permission-denied') return 'You don\u2019t have permission to do that.';
    if (e.code == 'unavailable') return 'Campus services are unreachable. Try again shortly.';
    return e.message ?? 'Something went wrong.';
  }
  return 'Something went wrong. Please try again.';
}

String friendlyErrorText(Object e) => friendlyError(e);
