import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place.dart';
import 'trip_providers.dart';          // ← 加這行，拿到 tripRepoProvider

final placesOfTripProvider =
    StreamProvider.family<List<Place>, String>((ref, tripId) {
  return ref.watch(tripRepoProvider).watchPlaces(tripId);
});
