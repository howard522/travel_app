import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/trip_repository.dart';
import '../models/trip.dart';
import 'auth_providers.dart';

/// TripRepository 的全域 Provider
final tripRepoProvider =
    Provider<TripRepository>((ref) => TripRepository());

/// 觀察目前登入者的 Trip 清單
final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(tripRepoProvider).watchTrips(user.uid);
});

/// 觀察單一 Trip 的即時資料
final tripProvider = StreamProvider.family<Trip, String>((ref, tripId) {
  return ref.watch(tripRepoProvider).watchTrip(tripId);
});
