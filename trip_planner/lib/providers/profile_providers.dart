// lib/providers/profile_providers.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/user_profile.dart';
import 'auth_providers.dart';

final userProfileProvider =
    StreamProvider.autoDispose<UserProfile?>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();

  final docRef = FirebaseFirestore.instance.collection('users').doc(user.uid);
  return docRef.snapshots().map((snap) {
    if (!snap.exists) return null;
    return UserProfile.fromJson(snap.id, snap.data()!);
  });
});
