import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import '../providers/trip_providers.dart';
import '../providers/auth_providers.dart';
import '../models/trip.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tripsAsync = ref.watch(userTripsProvider);
    final authRepo = ref.read(authRepoProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(onPressed: authRepo.signOut, icon: const Icon(Icons.logout))
        ],
      ),
      body: tripsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (trips) => trips.isEmpty
            ? const Center(child: Text('No trip yet'))
            : ListView.builder(
                itemCount: trips.length,
                itemBuilder: (_, i) => _TripTile(trip: trips[i]),
              ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addTripDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _addTripDialog(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('New Trip'),
        content: TextField(controller: title, decoration: const InputDecoration(hintText: 'Trip title')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).value!;
    final repo = ref.read(tripRepoProvider);
    await repo.addTrip(Trip(
      id: '_tmp',                       // Firestore 自動 ID
      title: title.text.trim(),
      owner: user.uid,
      members: [user.uid],
      startDate: DateTime.now(),
      endDate: DateTime.now().add(const Duration(days: 1)),
    ));
  }
}

class _TripTile extends StatelessWidget {
  const _TripTile({required this.trip});
  final Trip trip;
  @override
  Widget build(BuildContext context) => ListTile(
        title: Text(trip.title),
        subtitle: Text(
            '${trip.startDate.toLocal().toString().split(' ').first} ➜ ${trip.endDate.toLocal().toString().split(' ').first}'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/trip/${trip.id}'),
      );
}
