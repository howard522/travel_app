// lib/pages/home_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/auth_providers.dart';
import '../providers/trip_providers.dart';
import '../models/trip.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final myTrips = ref.watch(userTripsProvider);
    final invites = ref.watch(pendingTripInvitesProvider);
    final authRepo = ref.read(authRepoProvider);
    final tripRepo = ref.read(tripRepoProvider);
    final user = ref.watch(authStateProvider).value!;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            tooltip: '個人資料',
            onPressed: () => context.push('/profile'),
          ),
          IconButton(onPressed: authRepo.signOut, icon: const Icon(Icons.logout)),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            invites.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(8),
                child: Text('邀請讀取失敗：$e'),
              ),
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text('待接受邀請',
                              style: TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                        ),
                        for (final t in list)
                          ListTile(
                            title: Text(t.title),
                            subtitle: Text(
                              DateFormat('yyyy-MM-dd HH:mm')
                                  .format(t.startTime.toLocal()),
                            ),
                            trailing: ElevatedButton(
                              onPressed: () => tripRepo.acceptInvite(
                                t.id,
                                user.uid,
                                user.email!,
                              ),
                              child: const Text('接受'),
                            ),
                          ),
                        const Divider(height: 1),
                      ],
                    ),
            ),
            Expanded(
              child: myTrips.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(e.toString())),
                data: (list) => list.isEmpty
                    ? const Center(child: Text('No trip yet'))
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (_, i) => _TripTile(trip: list[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showNewTripDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  /* ---------- 新增 Trip Dialog ---------- */

  Future<void> _showNewTripDialog(BuildContext context, WidgetRef ref) async {
    final titleCtrl = TextEditingController();
    DateTime startAt = DateTime.now();

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Trip'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(hintText: 'Trip title'),
            ),
            const SizedBox(height: 16),
            ListTile(
              title: Text('Start: ${DateFormat('yyyy-MM-dd HH:mm').format(startAt)}'),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: startAt,
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2100),
                );
                if (date == null) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(startAt),
                );
                if (time == null) return;
                startAt = DateTime(date.year, date.month, date.day,
                    time.hour, time.minute);
                // rebuild dialog
                (context as Element).markNeedsBuild();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Add')),
        ],
      ),
    );

    if (ok != true || titleCtrl.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).value!;
    final repo = ref.read(tripRepoProvider);

    await repo.addTrip(
      Trip(
        id        : '_tmp',
        title     : titleCtrl.text.trim(),
        members   : [user.uid],
        invites   : [],
        startTime : startAt,
        endDate   : startAt.add(const Duration(days: 1)),
      ),
    );
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(trip.title),
      subtitle:
          Text(DateFormat('yyyy-MM-dd HH:mm').format(trip.startTime.toLocal())),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/trip/${trip.id}'),
    );
  }
}
