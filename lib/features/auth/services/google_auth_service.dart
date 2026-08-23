import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class GoogleAuthService {
  static final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId: '628880255448-qvtgouniidlkanp37l0nfh2pts26fth5.apps.googleusercontent.com',
    scopes: [
      'email',
      'profile',
      'openid',
    ],
  );

  static Future<GoogleSignInAccount?> signIn() async {
    try {
      final account = await _googleSignIn.signIn();
      return account;
    } catch (e) {
      debugPrint('Google Sign-In Error: $e');
      rethrow;
    }
  }

  static Future<GoogleSignInAuthentication?> getAuth(GoogleSignInAccount account) async {
    return await account.authentication;
  }

  static Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (e) {
      debugPrint('Google Sign-Out Error: $e');
    }
  }
}
