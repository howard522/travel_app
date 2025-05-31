import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';

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

    final scheme = Theme.of(context).colorScheme;
    final nfDate = DateFormat('yyyy-MM-dd HH:mm');

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          /* ---------- SliverAppBar ---------- */
          SliverAppBar(
            floating: true,
            pinned: true,
            expandedHeight: 120,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding: const EdgeInsetsDirectional.only(start: 16, bottom: 16),
              title: Text('My Trips',
                  style: TextStyle(
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  )),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      scheme.primaryContainer,
                      scheme.secondaryContainer,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.person),
                tooltip: '個人資料',
                onPressed: () => context.push('/profile'),
              ),
              IconButton(
                icon: const Icon(Icons.logout),
                onPressed: authRepo.signOut,
              ),
            ],
          ),

          /* ---------- 邀請區 ---------- */
          SliverToBoxAdapter(
            child: invites.when(
              loading: () => const SizedBox(), // 不閃 loader，保持乾淨
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('邀請讀取失敗：$e'),
              ),
              data: (list) => list.isEmpty
                  ? const SizedBox.shrink()
                  : Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
                            child: Text('待接受邀請',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                          ...list.map(
                            (t) => Card(
                              margin: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 4),
                              child: ListTile(
                                title: Text(t.title),
                                subtitle: Text(nfDate.format(t.startTime.toLocal())),
                                trailing: ElevatedButton(
                                  onPressed: () => tripRepo.acceptInvite(
                                    t.id,
                                    user.uid,
                                    user.email!,
                                  ),
                                  child: const Text('接受'),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),
          ),

          /* ---------- Trip 卡片列表 ---------- */
          myTrips.when(
            loading: () => _buildShimmerPlaceholder(),
            error: (e, _) => SliverFillRemaining(
              child: Center(child: Text(e.toString())),
            ),
            data: (list) => list.isEmpty
                ? const SliverFillRemaining(
                    child: Center(child: Text('No trip yet')),
                  )
                : SliverList.separated(
                    itemCount: list.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) => _TripCard(trip: list[i]),
                  ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),

      /* ---------- FAB：新增 Trip ---------- */
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showNewTripDialog(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('New Trip'),
      ),
    );
  }

  /* ---------- Shimmer 佔位 ---------- */

  Widget _buildShimmerPlaceholder() => SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Shimmer.fromColors(
              baseColor: Colors.grey[300]!,
              highlightColor: Colors.grey[100]!,
              child: Container(
                height: 84,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
          childCount: 5,
        ),
      );

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
                startAt = DateTime(
                    date.year, date.month, date.day, time.hour, time.minute);
                (context as Element).markNeedsBuild();
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (ok != true || titleCtrl.text.trim().isEmpty) return;

    final user = ref.read(authStateProvider).value!;
    final repo = ref.read(tripRepoProvider);

    await repo.addTrip(
      Trip(
        id: '_tmp',
        title: titleCtrl.text.trim(),
        members: [user.uid],
        invites: [],
        startTime: startAt,
        endDate: startAt.add(const Duration(days: 1)),
      ),
    );
  }
}

/* ───────────────────────────────────────────────
 * Trip Card + Hero
 * ──────────────────────────────────────────────*/

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final nf = DateFormat('yyyy-MM-dd HH:mm');
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Hero(
        tag: 'trip_${trip.id}',
        flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
          // 讓卡片在飛行中保持圓角
          return Material(
            color: Colors.transparent,
            child: ScaleTransition(
              scale: anim.drive(Tween(begin: 1.0, end: dir == HeroFlightDirection.push ? 1.15 : 1.0)
                  .chain(CurveTween(curve: Curves.easeInOut))),
              child: fromCtx.widget,
            ),
          );
        },
        child: Card(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 2,
          child: ListTile(
            title: Text(trip.title),
            subtitle: Text(nf.format(trip.startTime.toLocal())),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/trip/${trip.id}'),
          ),
        ),
      ),
    );
  }
}
