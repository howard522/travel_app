// lib/pages/trip_page.dart

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:reorderables/reorderables.dart';

import '../providers/place_providers.dart';
import '../providers/trip_providers.dart';
import '../repositories/trip_repository.dart';
import '../models/place.dart';
import '../services/place_search_service.dart';
import '../services/schedule_service.dart';
import 'expense_page.dart';

class TripPage extends ConsumerStatefulWidget {
  const TripPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  GoogleMapController? _map;
  static const _initPos =
      CameraPosition(target: LatLng(23.5, 121), zoom: 6.5);

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesOfTripProvider(widget.tripId));
    final repo = ref.read(tripRepoProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Trip Planner'),
          bottom: const TabBar(
            tabs: [
              Tab(text: '地圖'),
              Tab(text: '帳單'),
            ],
          ),
          actions: [
            IconButton(
              tooltip: '智慧最佳化路線',
              icon: const Icon(Icons.flash_on_outlined),
              onPressed: () async {
                final places = placesAsync.valueOrNull;
                if (places == null || places.length < 3) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('需要至少 3 個景點才能最佳化')),
                  );
                  return;
                }
                final apiKey = const String.fromEnvironment('ROUTES_API_KEY');
                if (apiKey.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('請以 --dart-define=ROUTES_API_KEY=... 執行')),
                  );
                  return;
                }
                final svc = ScheduleService(apiKey);
                final latlngs = places.map((p) => '${p.lat},${p.lng}').toList();
                try {
                  final order = await svc.optimize(latlngs);
                  final reordered = <Place>[
                    places.first,
                    for (final idx in order) places[idx],
                    places.last,
                  ];
                  await repo.reorderPlaces(widget.tripId, reordered);
                } catch (e) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text('$e')));
                }
              },
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // 第一頁：地圖 + 拖曳清單
            placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text(e.toString())),
              data: (places) => _buildMapWithList(places, repo),
            ),
            // 第二頁：帳單
            ExpensePage(tripId: widget.tripId),
          ],
        ),
      ),
    );
  }

  Widget _buildMapWithList(List<Place> places, TripRepository repo) {
    final markers = _buildMarkers(places);
    _fitBounds(markers);

    return Row(
      children: [
        // 地圖
        Expanded(
          flex: 2,
          child: GoogleMap(
            initialCameraPosition: _initPos,
            markers: markers,
            onMapCreated: (c) => _map = c,
            myLocationButtonEnabled: false,
          ),
        ),
        // 拖曳清單 + 新增按鈕
        Expanded(
          flex: 1,
          child: Column(
            children: [
              Expanded(
                child: ReorderableColumn(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  onReorder: (oldIdx, newIdx) async {
                    final reordered = [...places];
                    final item = reordered.removeAt(oldIdx);
                    reordered.insert(newIdx, item);
                    await repo.reorderPlaces(widget.tripId, reordered);
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
                          onPressed: () =>
                              repo.deletePlace(widget.tripId, p.id),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(8),
                child: ElevatedButton.icon(
                  onPressed: () => _addPlaceDialog(context, repo),
                  icon: const Icon(Icons.add),
                  label: const Text('新增景點'),
                ),
              ),
            ],
          ),
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
          )
      };

  void _fitBounds(Set<Marker> markers) {
    if (_map == null || markers.isEmpty) return;
    final lats = markers.map((m) => m.position.latitude);
    final lngs = markers.map((m) => m.position.longitude);
    final sw = LatLng(lats.reduce(min), lngs.reduce(min));
    final ne = LatLng(lats.reduce(max), lngs.reduce(max));
    _map!.animateCamera(
      CameraUpdate.newLatLngBounds(LatLngBounds(southwest: sw, northeast: ne), 48),
    );
  }

  Future<void> _addPlaceDialog(
      BuildContext context, TripRepository repo) async {
    final query = TextEditingController();
    List<PlaceSuggestion>? results;
    PlaceSuggestion? chosen;

    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(builder: (ctx, setState) {
        return AlertDialog(
          title: const Text('搜尋景點'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: query,
                decoration:
                    const InputDecoration(hintText: '輸入關鍵字，如「台北 101」'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final key =
                      const String.fromEnvironment('PLACES_API_KEY');
                  if (key.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('請以 --dart-define=PLACES_API_KEY=... 執行')),
                    );
                    return;
                  }
                  try {
                    results =
                        await PlaceSearchService(key).search(query.text.trim());
                  } catch (e) {
                    results = [];
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text('$e')));
                  }
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
                    itemBuilder: (_, i) => ListTile(
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
      }),
    );

    if (chosen == null) return;
    await repo.addPlace(
      widget.tripId,
      Place(
        id: '_tmp',
        name: chosen!.name,
        lat: chosen!.lat,
        lng: chosen!.lng,
        order: DateTime.now().millisecondsSinceEpoch,
        stayHours: 1,
        note: '',
      ),
    );
  }
}
