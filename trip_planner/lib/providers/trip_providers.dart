// lib/providers/trip_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/trip_repository.dart';
import '../models/trip.dart';
import 'auth_providers.dart';

/// 1. Repository 單例
final tripRepoProvider = Provider<TripRepository>((_) => TripRepository());

/// 2. 觀察「單一 Trip」── 供 ExpensePage 等功能使用
final tripProvider = StreamProvider.family<Trip, String>((ref, tripId) {
  return ref.watch(tripRepoProvider).watchTrip(tripId);
});

/// 3. 觀察目前登入者擁有/參與的 Trip 清單
final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(tripRepoProvider).watchTrips(user.uid);
});

