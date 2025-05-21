import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final authStateProvider =
    StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

/// Email 密碼登入 / 註冊
class AuthRepository {
  AuthRepository(this._auth);
  final FirebaseAuth _auth;

  Future<UserCredential> signInWithEmail(
      {required String email, required String pwd}) {
    return _auth.signInWithEmailAndPassword(email: email, password: pwd);
  }

  Future<UserCredential> registerWithEmail(
      {required String email, required String pwd}) {
    return _auth.createUserWithEmailAndPassword(email: email, password: pwd);
  }

  Future<UserCredential> signInWithGoogle() async {
    final gUser = await GoogleSignIn().signIn();
    if (gUser == null) throw Exception('Google sign-in aborted');
    final gAuth = await gUser.authentication;
    final cred = GoogleAuthProvider.credential(
      idToken: gAuth.idToken,
      accessToken: gAuth.accessToken,
    );
    return _auth.signInWithCredential(cred);
  }

  Future<void> signOut() => _auth.signOut();
}

final authRepoProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(firebaseAuthProvider)),
);
