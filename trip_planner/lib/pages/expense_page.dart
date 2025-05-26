import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';
import '../providers/expense_providers.dart';
import '../providers/trip_providers.dart';
import '../repositories/trip_repository.dart';
import 'add_expense_dialog.dart';

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expensesAsync = ref.watch(expensesOfTripProvider(tripId));
    final trip = ref.watch(tripProvider(tripId)).valueOrNull;
    final repo = ref.read(tripRepoProvider);

    return Scaffold(
      body: expensesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (exps) => exps.isEmpty
            ? const Center(child: Text('尚無帳單'))
            : ListView.builder(
                itemCount: exps.length,
                itemBuilder: (_, i) => _ExpenseTile(exp: exps[i]),
              ),
      ),
      floatingActionButton: trip == null
          ? null
          : FloatingActionButton(
              onPressed: () async {
                final exp = await showDialog<Expense>(
                  context: context,
                  builder: (_) => AddExpenseDialog(
                    tripId: tripId,
                    members: trip.members, // Trip model 應有 members 陣列
                  ),
                );
                if (exp != null) {
                  await repo.addExpense(tripId, exp);
                }
              },
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({required this.exp});
  final Expense exp;

  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(exp.title),
        subtitle: Text(
            '付款人：${exp.payerId} · 參與：${exp.sharedBy.length} 人'),
        trailing: Text(
          'NT\$ ${(exp.cents / 100).toStringAsFixed(0)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      );
}
