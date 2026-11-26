import 'package:firebase_auth/firebase_auth.dart';
import 'db.dart';

class AuthService {
  AuthService._();
  static FirebaseAuth get _auth => FirebaseAuth.instance;

  static Future<void> signIn(String email, String password) async {
    await _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  static Future<void> register({
    required String email,
    required String password,
    required String fullName,
    String? fieldOfStudy,
    int? yearOfStudy,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
    final user = cred.user!;
    await user.updateDisplayName(fullName.trim());
    await Db.createUserProfile(user,
        fullName: fullName, fieldOfStudy: fieldOfStudy, yearOfStudy: yearOfStudy);
    try {
      await user.sendEmailVerification();
    } catch (_) {
      // Not fatal: the user can resend from the banner later.
    }
  }

  static Future<void> sendPasswordReset(String email) =>
      _auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> resendVerification() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  static Future<void> signOut() => _auth.signOut();
}
