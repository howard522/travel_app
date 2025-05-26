import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/trip_repository.dart';
import '../models/expense.dart';
// 👇 引入定義了 tripRepoProvider 的檔案
import 'trip_providers.dart';

final expensesOfTripProvider =
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
  return ref.watch(tripRepoProvider).watchExpenses(tripId);
});
