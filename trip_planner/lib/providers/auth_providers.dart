// lib/providers/auth_providers.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  /// 如果 Firestore 裡沒有此 UID，就建立一筆預設的 user doc (含 gender, country)
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
        'gender'     : '', // 預設空白
        'country'    : '', // 預設空白
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
  /// 目前新增 gender, country 更新
  Future<void> updateUserProfile({
    String? displayName,
    String? bio,
    String? phone,
    String? gender,
    String? country,
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
    if (gender != null) {
      updates['gender'] = gender;
    }
    if (country != null) {
      updates['country'] = country;
    }
    if (updates.isNotEmpty) {
      await _firestore.collection('users').doc(user.uid).update(updates);
    }
  }

  /// 上傳頭像到 Firebase Storage，並同步更新 photoURL
  /// 改為指定路徑 avatars/{uid}.jpg
  Future<String> uploadAvatar(File file) async {
    final user = _auth.currentUser!;
    // 指定儲存路徑為 avatars/{uid}.jpg
    final ref = _storage.ref().child('avatars').child('${user.uid}.jpg');
    final uploadTask = ref.putFile(file);

    final snapshot = await uploadTask;
    if (snapshot.state == TaskState.success) {
      final url = await ref.getDownloadURL();
      // 更新 FirebaseAuth profile
      await user.updatePhotoURL(url);
      // 更新 Firestore 上的 user doc
      await _firestore.collection('users').doc(user.uid).update({
        'photoURL': url,
      });
      return url;
    } else {
      throw FirebaseException(
        plugin: 'firebase_storage',
        message: 'Avatar upload failed with state: ${snapshot.state}',
      );
    }
  }
}
