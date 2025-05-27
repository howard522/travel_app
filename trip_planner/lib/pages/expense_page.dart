import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../providers/expense_providers.dart';
import '../providers/trip_providers.dart';
import 'add_expense_dialog.dart';                    // 👈 新增

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key, required this.tripId});
  final String tripId;

  /* ---------- helpers ---------- */

  // 依參與者算出「誰欠付款人多少」－－只算這筆帳單
  Map<String, int> _split(Expense e) {
    final map  = <String, int>{};
    final base = e.cents ~/ e.sharedBy.length;
    var   extra= e.cents - base * e.sharedBy.length;
    for (final uid in e.sharedBy) {
      var share = base;
      if (extra > 0) { share++; extra--; }
      if (uid == e.payerId) continue;
      map[uid] = share;
    }
    return map;
  }

  /* ---------- UI ---------- */

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expsAsync  = ref.watch(openExpensesProvider(tripId));
    final settleAll  = ref.watch(settleAllProvider(tripId));
    final repo       = ref.watch(tripRepoProvider);
    final nf         = NumberFormat('#,##0');

    Future<void> _addExpense() async {
      // 先把 trip.members 拿來當表單的選擇清單
      final trip  = await ref.read(tripRepoProvider).watchTrip(tripId).first;
      final exp   = await showDialog<Expense>(
        context: context,
        builder: (_) => AddExpenseDialog(
          tripId : tripId,
          members: trip.members,
        ),
      );
      if (exp != null) await repo.addExpense(tripId, exp);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('帳單 / 結清'),
        actions: [
          IconButton(
            tooltip: '結餘',
            icon   : const Icon(Icons.stacked_bar_chart_outlined),
            onPressed: () => _showBalances(context, ref),
          ),
          if (expsAsync.isNotEmpty)
            TextButton(
              onPressed: () async => await settleAll(),
              child: const Text('全部結清', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon : const Icon(Icons.add),
        label: const Text('新增帳單'),
        onPressed: _addExpense,                         // 👈 新增
      ),
      body: expsAsync.isEmpty
          ? const Center(child: Text('✅ 目前沒有未結清帳單'))
          : ListView.separated(
              padding: const EdgeInsets.all(4),
              itemCount: expsAsync.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final e   = expsAsync[i];
                final owe = _split(e);

                return Card(
                  child: ExpansionTile(
                    leading : Checkbox(
                      value    : e.settled,
                      onChanged: (_) => repo.updateExpense(
                          tripId, e.id, {'settled': true}),
                    ),
                    title   : Text('${e.title}  NT\$${nf.format(e.cents / 100)}'),
                    subtitle: Text('付款人：${e.payerId}'),
                    children: [
                      for (final entry in owe.entries)
                        ListTile(
                          dense: true,
                          title: Text(
                            '${entry.key} 欠 ${e.payerId}  '
                            'NT\$${nf.format(entry.value / 100)}',
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  /* ---------- balances dialog ---------- */

  void _showBalances(BuildContext ctx, WidgetRef ref) {
    final bal = ref.read(balancesProvider(tripId));
    if (bal.isEmpty) return;

    final list = bal.entries.toList()
      ..sort((a, b) => -a.value.compareTo(b.value));
    final nf = NumberFormat('#,##0');
    showDialog(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('淨餘 (未結清)'),
        content: SizedBox(
          width: 260,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: list.length,
            itemBuilder: (_, i) {
              final e = list[i];
              final sign  = e.value >= 0 ? '+' : '-';
              final color = e.value == 0 ? null
                           : (e.value > 0 ? Colors.green : Colors.red);
              return ListTile(
                dense : true,
                title : Text(e.key),
                trailing: Text(
                  '$sign${nf.format(e.value.abs() / 100)}',
                  style: TextStyle(color: color),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('關閉'),
          ),
        ],
      ),
    );
  }
}
