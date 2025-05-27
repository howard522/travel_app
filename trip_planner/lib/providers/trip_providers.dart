import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/trip_repository.dart';
import '../models/trip.dart';
import 'auth_providers.dart';

final tripRepoProvider =
    Provider<TripRepository>((_) => TripRepository());

/// 自己是成員的行程
final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final uid = ref.watch(authStateProvider).value?.uid;
  if (uid == null) return const Stream.empty();
  return ref.watch(tripRepoProvider).watchTrips(uid);
});

/// 等待我接受的邀請
final pendingTripInvitesProvider =
    StreamProvider<List<Trip>>((ref) {
  final email = ref.watch(authStateProvider).value?.email;
  if (email == null) return const Stream.empty();
  return ref
      .watch(tripRepoProvider)
      .watchTripsByInvite(email);
});

/// 單一 Trip 的 invites 清單（字串列表）
final pendingInvitesProvider =
    StreamProvider.family<List<String>, String>((ref, tripId) {
  return ref
      .watch(tripRepoProvider)
      .watchTrip(tripId)
      .map((t) => t.invites);
});
