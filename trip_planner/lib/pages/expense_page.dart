// lib/pages/expense_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/expense.dart';
import '../providers/expense_providers.dart';
import '../providers/trip_providers.dart';
import '../providers/profile_providers.dart';
import 'add_expense_dialog.dart';

class ExpensePage extends ConsumerWidget {
  const ExpensePage({super.key, required this.tripId});
  final String tripId;

  // 只算這筆帳單的「誰欠付款人多少」
  Map<String, int> _split(Expense e) {
    final map = <String, int>{};
    final base = e.cents ~/ e.sharedBy.length;
    var extra = e.cents - base * e.sharedBy.length;
    for (final uid in e.sharedBy) {
      var share = base;
      if (extra > 0) {
        share++;
        extra--;
      }
      if (uid == e.payerId) continue;
      map[uid] = share;
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expsAsync = ref.watch(expensesOfTripProvider(tripId));
    final repo = ref.read(tripRepoProvider);
    final nf = NumberFormat('#,##0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('帳單 / 結清'),
        actions: [
          IconButton(
            tooltip: '結餘',
            icon: const Icon(Icons.stacked_bar_chart_outlined),
            onPressed: () => _showBalances(context, ref),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('新增帳單'),
        onPressed: () async {
          final trip = await ref.read(tripRepoProvider).watchTrip(tripId).first;
          final exp = await showDialog<Expense>(
            context: context,
            builder: (_) => AddExpenseDialog(
              tripId: tripId,
              members: trip.members,
            ),
          );
          if (exp != null) await repo.addExpense(tripId, exp);
        },
      ),
      body: expsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('✅ 目前沒有未結清帳單'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(4),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final e = list[i];
              final owe = _split(e);
              // 樣式：已結清打勾 + 刪除線 + 灰色
              final textStyle = e.settled
                  ? const TextStyle(
                      decoration: TextDecoration.lineThrough,
                      color: Colors.grey)
                  : null;

              return Card(
                child: ExpansionTile(
                  leading: Checkbox(
                    value: e.settled,
                    onChanged: (_) =>
                        repo.updateExpense(tripId, e.id, {'settled': true}),
                  ),
                  // 標題：金額顯示 + 刪除按鈕
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${e.title}  NT\$${nf.format(e.cents / 100)}',
                          style: textStyle,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () =>
                            repo.deleteExpense(tripId, e.id),
                      ),
                    ],
                  ),
                  // 副標題：顯示付款人名稱
                  subtitle: Consumer(
                    builder: (context, ref, _) {
                      final payerAsync = ref.watch(
                          userProfileProviderFamily(e.payerId));
                      return payerAsync.when(
                        data: (profile) {
                          final name = profile?.displayName.isNotEmpty == true
                              ? profile!.displayName
                              : e.payerId;
                          return Text('付款人：$name', style: textStyle);
                        },
                        loading: () =>
                            Text('付款人：${e.payerId}', style: textStyle),
                        error: (_, __) =>
                            Text('付款人：${e.payerId}', style: textStyle),
                      );
                    },
                  ),
                  children: [
                    for (final entry in owe.entries)
                      Consumer(
                        builder: (context, ref, _) {
                          final profileAsync = ref.watch(
                              userProfileProviderFamily(entry.key));
                          return profileAsync.when(
                            data: (profile) {
                              final name = profile?.displayName.isNotEmpty ==
                                      true
                                  ? profile!.displayName
                                  : entry.key;
                              return ListTile(
                                dense: true,
                                title: Text(
                                  '$name 欠 NT\$${nf.format(entry.value / 100)}',
                                  style: textStyle,
                                ),
                              );
                            },
                            loading: () => ListTile(
                              dense: true,
                              title: Text(
                                '${entry.key} 欠 NT\$${nf.format(entry.value / 100)}',
                                style: textStyle,
                              ),
                            ),
                            error: (_, __) => ListTile(
                              dense: true,
                              title: Text(
                                '${entry.key} 欠 NT\$${nf.format(entry.value / 100)}',
                                style: textStyle,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

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
              final sign = e.value >= 0 ? '+' : '-';
              final color = e.value == 0
                  ? null
                  : (e.value > 0 ? Colors.green : Colors.red);
              return ListTile(
                dense: true,
                title: Text(e.key),
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
