import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/trip_repository.dart';

/// 任何畫面如果需要 TripRepository，直接 ref.watch(tripRepoProvider)
final tripRepoProvider = Provider<TripRepository>((ref) {
  return TripRepository();
});
