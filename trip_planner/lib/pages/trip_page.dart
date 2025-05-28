import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reorderables/reorderables.dart';
import 'package:go_router/go_router.dart';

import '../providers/place_providers.dart';
import '../providers/trip_providers.dart';
import '../repositories/trip_repository.dart';
import '../models/place.dart';
import '../services/place_search_service.dart';
import 'add_invite_dialog.dart';

class TripPage extends ConsumerStatefulWidget {
  const TripPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _map;
  static const _initPos = CameraPosition(target: LatLng(23.5, 121), zoom: 6.5);

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesOfTripProvider(widget.tripId));
    final pendingAsync = ref.watch(pendingInvitesProvider(widget.tripId));
    final repo = ref.read(tripRepoProvider);

    return Scaffold(
      key: _scaffoldKey,
      appBar: AppBar(
        title: const Text('Trip Planner'),
        actions: [
          // 打開右側側邊欄
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: '操作面板',
          ),
        ],
      ),

      // 右側側邊欄
      endDrawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data:
                  (places) =>
                      _buildSidePanel(context, places, pendingAsync, repo),
            ),
          ),
        ),
      ),

      // 主體只顯示地圖
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (places) {
          final markers = _buildMarkers(places);
          _fitBounds(markers);
          return GoogleMap(
            initialCameraPosition: _initPos,
            markers: markers,
            onMapCreated: (c) => _map = c,
            myLocationButtonEnabled: false,
          );
        },
      ),
    );
  }

  Widget _buildSidePanel(
    BuildContext context,
    List<Place> places,
    AsyncValue<List<String>> pendingAsync,
    TripRepository repo,
  ) {
    return Column(
      children: [
        // 拖曳排序清單
        Expanded(
          child: ReorderableColumn(
            crossAxisAlignment: CrossAxisAlignment.start,
            onReorder: (oldIdx, newIdx) async {
              final list = [...places];
              final item = list.removeAt(oldIdx);
              list.insert(newIdx, item);
              await repo.reorderPlaces(widget.tripId, list);
            },
            children: [
              for (final p in places)
                ListTile(
                  key: ValueKey(p.id),
                  title: Text(p.name),
                  subtitle: Text(
                    '${p.lat.toStringAsFixed(4)}, ${p.lng.toStringAsFixed(4)}',
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => repo.deletePlace(widget.tripId, p.id),
                  ),
                ),
            ],
          ),
        ),

        // Pending 邀請
        pendingAsync.when(
          data: (invites) {
            if (invites.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '等待接受邀請',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(
                    height: 80,
                    child: ListView(
                      children:
                          invites
                              .map(
                                (e) => Text(
                                  '• $e',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              )
                              .toList(),
                    ),
                  ),
                ],
              ),
            );
          },
          loading:
              () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: CircularProgressIndicator(),
              ),
          error:
              (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(e.toString()),
              ),
        ),

        const Divider(),

        // 操作按鈕
        OverflowBar(
          spacing: 8,
          overflowSpacing: 8,
          alignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () => _addPlaceDialog(context, repo),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('新增景點'),
            ),
            OutlinedButton.icon(
              onPressed:
                  () => showDialog(
                    context: context,
                    builder: (_) => AddInviteDialog(tripId: widget.tripId),
                  ),
              icon: const Icon(Icons.mail_outlined),
              label: const Text('邀請成員'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                context.push('/trip/${widget.tripId}/expense');
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text('帳單'),
            ),
            OutlinedButton.icon(
              onPressed: () => context.push('/trip/${widget.tripId}/chat'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('聊天室'),
            ),
          ],
        ),
      ],
    );
  }

  Set<Marker> _buildMarkers(List<Place> places) => {
    for (var i = 0; i < places.length; i++)
      Marker(
        markerId: MarkerId(places[i].id),
        position: LatLng(places[i].lat, places[i].lng),
        infoWindow: InfoWindow(title: '${i + 1}. ${places[i].name}'),
      ),
  };

  void _fitBounds(Set<Marker> markers) {
    if (_map == null || markers.isEmpty) return;
    final latitudes = markers.map((m) => m.position.latitude);
    final longitudes = markers.map((m) => m.position.longitude);
    final sw = LatLng(latitudes.reduce(min), longitudes.reduce(min));
    final ne = LatLng(latitudes.reduce(max), longitudes.reduce(max));
    _map!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        48,
      ),
    );
  }

  Future<void> _addPlaceDialog(
    BuildContext context,
    TripRepository repo,
  ) async {
    final query = TextEditingController();
    List<PlaceSuggestion>? results;
    PlaceSuggestion? chosen;

    await showDialog(
      context: context,
      builder:
          (_) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: const Text('搜尋景點'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: query,
                      decoration: const InputDecoration(hintText: '輸入關鍵字'),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () async {
                        final key = const String.fromEnvironment(
                          'PLACES_API_KEY',
                        );
                        if (key.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '請用 --dart-define=PLACES_API_KEY=...',
                              ),
                            ),
                          );
                          return;
                        }
                        results = await PlaceSearchService(
                          key,
                        ).search(query.text);
                        setState(() {});
                      },
                      child: const Text('搜尋'),
                    ),
                    if (results != null)
                      SizedBox(
                        height: 240,
                        width: 300,
                        child: ListView.builder(
                          itemCount: results!.length,
                          itemBuilder:
                              (_, i) => ListTile(
                                title: Text(results![i].name),
                                onTap: () {
                                  chosen = results![i];
                                  Navigator.pop(ctx);
                                },
                              ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
    );

    if (chosen == null) return;
    final sel = chosen!;
    await repo.addPlace(
      widget.tripId,
      Place(
        id: '_tmp',
        name: sel.name,
        lat: sel.lat,
        lng: sel.lng,
        order: DateTime.now().millisecondsSinceEpoch,
        stayHours: 1,
        note: '',
      ),
    );
  }
}
