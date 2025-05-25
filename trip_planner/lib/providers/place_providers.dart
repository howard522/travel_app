import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/place.dart';
import '../repositories/trip_repository.dart';
import 'repo_providers.dart';

/// StreamProvider.family 依 tripId 監聽 places，並以 `order` 排序
final placesProvider =
    StreamProvider.family<List<Place>, String>((ref, tripId) {
  final repo = ref.read(tripRepoProvider);
  return repo.watchPlaces(tripId);
});
