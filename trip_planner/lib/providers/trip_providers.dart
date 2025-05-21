import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/trip_repository.dart';
import 'auth_providers.dart';
import '../models/trip.dart';

final tripRepoProvider = Provider<TripRepository>((_) => TripRepository());

/// 觀察目前登入者的 Trip 清單
final userTripsProvider = StreamProvider<List<Trip>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return const Stream.empty();
  return ref.watch(tripRepoProvider).watchTrips(user.uid);
});
