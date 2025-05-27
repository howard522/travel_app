import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/expense.dart';
import '../repositories/trip_repository.dart';
import 'trip_providers.dart';

/* ---------------- 帳單串流 ---------------- */

final expensesOfTripProvider =
    StreamProvider.family<List<Expense>, String>((ref, tripId) {
  return ref.watch(tripRepoProvider).watchExpenses(tripId);
});

/* 只取還沒結清的 */
final openExpensesProvider =
    Provider.family<List<Expense>, String>((ref, tripId) {
  final exps = ref.watch(expensesOfTripProvider(tripId)).value ?? [];
  return exps.where((e) => !e.settled).toList();
});

/* ---------------- 淨餘計算 ---------------- */

final balancesProvider =
    Provider.family<Map<String, int>, String>((ref, tripId) {
  final exps = ref.watch(openExpensesProvider(tripId));   // 只算未結清
  final result = <String, int>{};

  for (final e in exps) {
    result.update(e.payerId, (v) => v + e.cents, ifAbsent: () => e.cents);

    final base = e.cents ~/ e.sharedBy.length;
    var extra  = e.cents - base * e.sharedBy.length;
    for (final uid in e.sharedBy) {
      var share = base;
      if (extra > 0) { share++; extra--; }
      result.update(uid, (v) => v - share, ifAbsent: () => -share);
    }
  }
  return result;
});

/* ---------------- Action：全部結清 ---------------- */

final settleAllProvider =
    Provider.family<Future<void> Function(), String>((ref, tripId) {
  final repo = ref.watch(tripRepoProvider);
  return () async {
    final exps = ref.read(openExpensesProvider(tripId));
    for (final e in exps) {
      await repo.updateExpense(tripId, e.id, {'settled': true});
    }
  };
});
