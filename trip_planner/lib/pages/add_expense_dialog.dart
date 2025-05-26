import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense.dart';

class AddExpenseDialog extends ConsumerStatefulWidget {
  const AddExpenseDialog({
    super.key,
    required this.tripId,
    required this.members, // trip.members 的 uid 列表
  });

  final String tripId;
  final List<String> members;

  @override
  ConsumerState<AddExpenseDialog> createState() =>
      _AddExpenseDialogState();
}

class _AddExpenseDialogState extends ConsumerState<AddExpenseDialog> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _money = TextEditingController();

  late String _payer;         // 單選
  late Set<String> _sharedBy; // 多選

  @override
  void initState() {
    super.initState();
    _payer = widget.members.first;
    _sharedBy = {...widget.members};
  }

  @override
  void dispose() {
    _title.dispose();
    _money.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('新增帳單'),
      // ---- 關鍵：限制寬度並允許內容垂直捲動 ----
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 標題
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: '標題'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '必填' : null,
                ),
                const SizedBox(height: 12),
                // 金額
                TextFormField(
                  controller: _money,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '金額 (NT\$)'),
                  validator: (v) =>
                      (v == null || double.tryParse(v.trim()) == null)
                          ? '請輸入數字'
                          : null,
                ),
                const SizedBox(height: 16),
                // 付款人
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('付款人'),
                ),
                DropdownButton<String>(
                  value: _payer,
                  isExpanded: true,
                  items: [
                    for (final m in widget.members)
                      DropdownMenuItem(value: m, child: Text(m))
                  ],
                  onChanged: (v) => setState(() => _payer = v!),
                ),
                const SizedBox(height: 16),
                // 參與者
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text('參與者'),
                ),
                SizedBox(
                  height: 160,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: widget.members.length,
                    itemBuilder: (_, i) {
                      final m = widget.members[i];
                      return CheckboxListTile(
                        dense: true,
                        value: _sharedBy.contains(m),
                        title: Text(m),
                        onChanged: (v) => setState(() {
                          v!
                              ? _sharedBy.add(m)
                              : _sharedBy.remove(m);
                        }),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;

            if (_sharedBy.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('至少要有 1 位參與者')),
              );
              return;
            }

            final cents =
                (double.parse(_money.text.trim()) * 100).round(); // 轉為「分」

            final exp = Expense(
              id: '_tmp',
              title: _title.text.trim(),
              cents: cents,
              payerId: _payer,
              sharedBy: _sharedBy.toList(),
              createdAt: DateTime.now(),
            );

            Navigator.pop(context, exp); // 回傳 Expense 給呼叫頁
          },
          child: const Text('儲存'),
        ),
      ],
    );
  }
}
