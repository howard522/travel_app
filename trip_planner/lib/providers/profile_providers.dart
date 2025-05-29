// lib/providers/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'auth_providers.dart';

/* ---------- 單一使用者 ---------- */

final userProfileProvider = StreamProvider.autoDispose<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  return docRef.snapshots().map(
        (snap) => snap.exists ? UserProfile.fromJson(snap.id, snap.data()!) : null,
      );
});

final userProfileProviderFamily =
    StreamProvider.family<UserProfile?, String>((ref, uid) {
  final docRef = FirebaseFirestore.instance.collection('users').doc(uid);
  return docRef.snapshots().map(
        (snap) => snap.exists ? UserProfile.fromJson(snap.id, snap.data()!) : null,
      );
});

/* ---------- 快取所有查過的使用者 ---------- */

class UserProfileCache extends StateNotifier<Map<String, UserProfile>> {
  UserProfileCache(this._ref) : super({});
  final Ref _ref;

  /// 取一筆，如果快取沒有就自動去 Firestore 抓一次後放進快取
  Future<UserProfile?> get(String uid) async {
    if (state.containsKey(uid)) return state[uid];
    final snap =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    final profile = UserProfile.fromJson(uid, snap.data()!);
    state = {...state, uid: profile};
    return profile;
  }
}

final userProfileCacheProvider =
    StateNotifierProvider<UserProfileCache, Map<String, UserProfile>>(
        (ref) => UserProfileCache(ref));
