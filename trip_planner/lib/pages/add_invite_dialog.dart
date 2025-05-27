import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trip_providers.dart';

class AddInviteDialog extends ConsumerStatefulWidget {
  const AddInviteDialog({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<AddInviteDialog> createState() => _AddInviteDialogState();
}

class _AddInviteDialogState extends ConsumerState<AddInviteDialog> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('邀請成員'),
      content: Form(
        key: _form,
        child: TextFormField(
          controller: _email,
          decoration: const InputDecoration(labelText: 'Email'),
          validator: (v) =>
              v != null && v.contains('@') ? null : '請輸入有效 Email',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
        FilledButton(
          child: const Text('送出'),
          onPressed: () async {
            if (!_form.currentState!.validate()) return;
            final repo = ref.read(tripRepoProvider);
            await repo.sendInvite(widget.tripId, _email.text.trim());
            if (context.mounted) Navigator.pop(context);
          },
        ),
      ],
    );
  }
}
