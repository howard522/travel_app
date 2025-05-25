import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../repositories/trip_repository.dart';

final tripRepoProvider = Provider<TripRepository>((_) => TripRepository());
