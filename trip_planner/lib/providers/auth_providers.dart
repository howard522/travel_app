// lib/providers/auth_providers.dart
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

final firebaseStorageProvider =
    Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

final authRepoProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(firebaseFirestoreProvider),
      ref.watch(firebaseStorageProvider),
    ));

final authStateProvider =
    StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

class AuthRepository {
  AuthRepository(this._auth, this._firestore, this._storage);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// 如果 Firestore 裡沒有此 UID，則建立一筆預設 user doc
  Future<void> _ensureUserDocExists(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'displayName': user.displayName ?? '',
        'email'      : user.email ?? '',
        'photoURL'   : user.photoURL ?? '',
        'bio'        : '',
        'phone'      : '',
      });
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String pwd,
  }) async {
    final cred =
        await _auth.signInWithEmailAndPassword(email: email, password: pwd);
    await _ensureUserDocExists(cred.user!);
    return cred;
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String pwd,
  }) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: pwd,
    );
    await _ensureUserDocExists(cred.user!);
    return cred;
  }

  Future<UserCredential> signInWithGoogle() async {
    final gUser = await GoogleSignIn().signIn();
    if (gUser == null) throw Exception('Google sign-in aborted');
    final gAuth = await gUser.authentication;
    final cred = await _auth.signInWithCredential(
      GoogleAuthProvider.credential(
        idToken: gAuth.idToken,
        accessToken: gAuth.accessToken,
      ),
    );
    await _ensureUserDocExists(cred.user!);
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  /// 更新使用者在 Firestore 上的 profile 欄位，並同步更新 FirebaseAuth
  Future<void> updateUserProfile({
    String? displayName,
    String? bio,
    String? phone,
  }) async {
    final user = _auth.currentUser!;
    final updates = <String, dynamic>{};
    if (displayName != null) {
      updates['displayName'] = displayName;
      await user.updateDisplayName(displayName);
    }
    if (bio != null) {
      updates['bio'] = bio;
    }
    if (phone != null) {
      updates['phone'] = phone;
    }
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(user.uid).update(updates);
    }
  }

  /// 上傳頭像到 Firebase Storage，更新 photoURL
  Future<String> uploadAvatar(File file) async {
    final user = _auth.currentUser!;
    final ref = _storage.ref('avatars/${user.uid}');
    await ref.putFile(file);
    final url = await ref.getDownloadURL();
    await user.updatePhotoURL(url);
    await _firestore.collection('users').doc(user.uid).update({
      'photoURL': url,
    });
    return url;
  }
}
