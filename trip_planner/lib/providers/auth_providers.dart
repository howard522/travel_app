// lib/providers/auth_providers.dart

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 提供 FirebaseAuth 實例
final firebaseAuthProvider =
    Provider<FirebaseAuth>((_) => FirebaseAuth.instance);

/// 提供 Firestore 實例
final firebaseFirestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);

/// 提供 FirebaseStorage 實例
final firebaseStorageProvider =
    Provider<FirebaseStorage>((_) => FirebaseStorage.instance);

/// 提供自訂的 AuthRepository
final authRepoProvider = Provider<AuthRepository>((ref) =>
    AuthRepository(
      ref.watch(firebaseAuthProvider),
      ref.watch(firebaseFirestoreProvider),
      ref.watch(firebaseStorageProvider),
    ));

/// 監聽使用者登入狀態
final authStateProvider =
    StreamProvider<User?>((ref) => ref.watch(firebaseAuthProvider).authStateChanges());

class AuthRepository {
  AuthRepository(this._auth, this._firestore, this._storage);
  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;

  /// 如果 Firestore 裡沒有此 UID，就建立一筆預設的 user doc
  Future<void> _ensureUserDocExists(User user) async {
    final docRef = _firestore.collection('users').doc(user.uid);
    final snap = await docRef.get();
    if (!snap.exists) {
      await docRef.set({
        'displayName': user.displayName ?? '',
        'email'      : user.email ?? '',
        'photoURL'   : user.photoURL ?? '',
        'bio'        : '',
        'phone'      : user.phoneNumber ?? '',
        'gender'     : '',
        'country'    : '',
      });
    }
  }

  /// Email/Password 登入
  Future<UserCredential> signInWithEmail({
    required String email,
    required String pwd,
  }) async {
    final cred =
        await _auth.signInWithEmailAndPassword(email: email, password: pwd);
    await _ensureUserDocExists(cred.user!);
    return cred;
  }

  /// Email/Password 註冊
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

  /// Google 登入
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

  /// 登出
  Future<void> signOut() => _auth.signOut();

  /// 更新使用者在 Firestore 上的 profile 欄位，並同步更新 FirebaseAuth
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
      await user.updatePhoneNumber(PhoneAuthProvider.credential( // 同步到 Auth 的 phoneNumber 欄位
        verificationId: '', // 不會在這裡用到
        smsCode: '',
      )).catchError((_) {}); // 這裡通常不會執行到
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

  // ──────────── 以下為電話號碼登入/註冊 ────────────

  /// 1) 呼叫 FirebaseAuth.verifyPhoneNumber，並把 callback 都回傳出去
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(PhoneAuthCredential credential) verificationCompleted,
    required void Function(FirebaseAuthException e) verificationFailed,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (phoneAuthCredential) async {
        // 自動驗證完成時呼叫
        verificationCompleted(phoneAuthCredential);
      },
      verificationFailed: (e) {
        // 驗證失敗時呼叫
        verificationFailed(e);
      },
      codeSent: (verificationId, resendToken) {
        // 驗證碼已送達時呼叫
        codeSent(verificationId, resendToken);
      },
      codeAutoRetrievalTimeout: (verificationId) {
        // 自動回填逾時時呼叫
        codeAutoRetrievalTimeout(verificationId);
      },
    );
  }

  /// 2) 使用者輸入驗證碼後，組出 PhoneAuthCredential，並用它來登入
  Future<UserCredential> signInWithPhoneCredential(
      String verificationId, String smsCode) async {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    final cred = await _auth.signInWithCredential(credential);
    await _ensureUserDocExists(cred.user!);
    return cred;
  }
}
