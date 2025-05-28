// lib/providers/profile_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'auth_providers.dart';

/// 監聽目前登入使用者自己的 Profile
final userProfileProvider =
    StreamProvider.autoDispose<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid);
  return docRef.snapshots().map((snap) {
    if (!snap.exists) return null;
    return UserProfile.fromJson(snap.id, snap.data()!);
  });
});

/// 監聽任一使用者 UID 的 Profile，用於聊天室顯示名稱
final userProfileProviderFamily =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  final docRef = FirebaseFirestore.instance
      .collection('users')
      .doc(uid);
  return docRef.snapshots().map((snap) {
    if (!snap.exists) return null;
    return UserProfile.fromJson(snap.id, snap.data()!);
  });
});
