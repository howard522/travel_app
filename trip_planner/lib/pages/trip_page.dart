import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../providers/place_providers.dart';
import '../providers/trip_providers.dart';
import '../models/place.dart';
import '../services/place_search_service.dart';
import '../repositories/trip_repository.dart';   // ← 新增這行


class TripPage extends ConsumerStatefulWidget {
  const TripPage({super.key, required this.tripId});
  final String tripId;

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  GoogleMapController? _map;
  static const _initPos = CameraPosition(
      target: LatLng(23.5, 121.0), zoom: 6.5); // 臺灣中心

  @override
  Widget build(BuildContext context) {
    final placesAsync = ref.watch(placesOfTripProvider(widget.tripId));
    final repo = ref.read(tripRepoProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Trip Map')),
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

      /// —— 新增 FloatingActionButton：「＋」搜尋景點並加入 —— ///
      floatingActionButton: FloatingActionButton(
        onPressed: () => _addPlaceDialog(context, repo),
        child: const Icon(Icons.add),
      ),
    );
  }

  /* ---------- 下面都是私人方法 ---------- */

  Set<Marker> _buildMarkers(List<Place> places) => {
        for (final p in places)
          Marker(
            markerId: MarkerId(p.id),
            position: LatLng(p.lat, p.lng),
            infoWindow: InfoWindow(title: p.name),
          )
      };

  void _fitBounds(Set<Marker> markers) {
    if (_map == null || markers.isEmpty) return;
    final lat = markers.map((m) => m.position.latitude);
    final lng = markers.map((m) => m.position.longitude);
    final sw = LatLng(lat.reduce(min), lng.reduce(min));
    final ne = LatLng(lat.reduce(max), lng.reduce(max));
    _map!.animateCamera(
      CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: sw, northeast: ne), 48),
    );
  }

  /// —— 對話框：輸入關鍵字 → API 搜尋 → 選取加入 —— ///
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
                    final key = const String.fromEnvironment('PLACES_API_KEY');
                    if (key.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('請以 --dart-define=PLACES_API_KEY=... 執行')));
                      return;
                    }
                    final svc = PlaceSearchService(key);
                    try {
                      results = await svc.search(query.text.trim());
                      setState(() {}); // refresh list
                    } catch (e) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  },
                  child: const Text('搜尋')),
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

    // 使用者選了一筆 → 寫入 Firestore
    if (chosen == null) return;
    await repo.addPlace(
      widget.tripId,
      Place(
        id: '_tmp', // 讓 repository 產生隨機 docId
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
