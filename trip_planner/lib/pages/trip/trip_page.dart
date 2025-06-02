import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/trip.dart';
import '../../models/place.dart';
import '../../providers/trip_providers.dart';
import '../../providers/place_providers.dart';
import '../add_invite_dialog.dart';
import 'trip_map_view.dart';
import 'trip_side_panel.dart';

/// TripPage: 頂層 Container
class TripPage extends ConsumerStatefulWidget {
  const TripPage({Key? key, required this.tripId}) : super(key: key);
  final String tripId;

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  TabController? _tabController;
  late List<DateTime> tripDates;

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tripRepo = ref.read(tripRepoProvider);

    return StreamBuilder<Trip>(
      stream: tripRepo.watchTrip(widget.tripId),
      builder: (context, tripSnapshot) {
        if (tripSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (tripSnapshot.hasError || !tripSnapshot.hasData) {
          return Scaffold(
            body: Center(
              child:
                  Text('Error loading trip: ${tripSnapshot.error ?? 'No data'}'),
            ),
          );
        }

        final trip = tripSnapshot.data!;
        // 計算日期列表 (純日期)
        final startDate = DateTime(
            trip.startTime.year, trip.startTime.month, trip.startTime.day);
        final endDate = DateTime(
            trip.endDate.year, trip.endDate.month, trip.endDate.day);
        tripDates = [];
        for (var d = startDate; !d.isAfter(endDate); d = d.add(const Duration(days: 1))) {
          tripDates.add(d);
        }

        // 初始化或更新 TabController
        if (_tabController == null || _tabController!.length != tripDates.length) {
          _tabController?.dispose();
          _tabController = TabController(length: tripDates.length, vsync: this);
        }

        // 監聽整個 Trip 下的所有 Place
        final placesAsync = ref.watch(placesOfTripProvider(widget.tripId));
        // 監聽邀請清單
        final pendingAsync = ref.watch(pendingInvitesProvider(widget.tripId));

        return Scaffold(
          key: _scaffoldKey,
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => context.pop(),
            ),
            title: Hero(
              tag: 'trip_${trip.id}',
              child: Material(
                type: MaterialType.transparency,
                child: Text(trip.title,
                    style: Theme.of(context).textTheme.titleLarge),
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                for (final date in tripDates)
                  Tab(text: DateFormat('MM/dd').format(date)),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.menu),
                tooltip: '操作面板',
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
              ),
            ],
          ),
          endDrawer: Drawer(
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: TripSidePanel(
                  trip: trip,
                  tripDates: tripDates,
                  placesAsync: placesAsync,
                  pendingInvitesAsync: pendingAsync,
                  tabController: _tabController!,
                ),
              ),
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              for (int i = 0; i < tripDates.length; i++)
                TripMapView(
                  trip: trip,
                  day: tripDates[i],
                  placesAsync: placesAsync,
                  onMapTap: (pos) async {
                    // 點地圖新增自訂景點
                    final nameCtrl = TextEditingController();
                    final ok = await showModalBottomSheet<bool>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => Padding(
                        padding: EdgeInsets.only(
                            bottom: MediaQuery.of(context).viewInsets.bottom),
                        child: Wrap(
                          children: [
                            const ListTile(title: Text('新增自訂景點')),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  TextField(
                                    controller: nameCtrl,
                                    decoration: const InputDecoration(labelText: '景點名稱'),
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(context, false),
                                        child: const Text('取消'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () => Navigator.pop(context, true),
                                        child: const Text('加入景點'),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
                      await tripRepo.addPlace(
                        widget.tripId,
                        Place(
                          id: '_tmp',
                          name: nameCtrl.text.trim(),
                          lat: pos.latitude,
                          lng: pos.longitude,
                          order: DateTime.now().millisecondsSinceEpoch,
                          stayHours: 1,
                          note: '',
                          date: tripDates[i],
                        ),
                      );
                    }
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}
