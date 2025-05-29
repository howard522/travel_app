// lib/pages/trip_page.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:reorderables/reorderables.dart';
import 'package:intl/intl.dart';

import '../models/place.dart';
import '../models/segment_info.dart';
import '../providers/place_providers.dart';
import '../providers/trip_providers.dart';
import '../repositories/trip_repository.dart';
import '../services/place_search_service.dart';
import '../services/schedule_service.dart';
import 'add_invite_dialog.dart';

class TripPage extends ConsumerStatefulWidget {
  const TripPage({Key? key, required this.tripId}) : super(key: key);
  final String tripId;

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  GoogleMapController? _map;
  static const _initPos = CameraPosition(target: LatLng(23.5, 121), zoom: 6.5);

  Set<Polyline> _polylines = {};
  Map<String, String> _durationsMap = {};
  List<String> _modes = [];

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
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            tooltip: '操作面板',
          ),
        ],
      ),
      endDrawer: Drawer(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: placesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
              data: (places) =>
                  _buildSidePanel(context, places, pendingAsync, repo),
            ),
          ),
        ),
      ),
      body: placesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (places) {
          final markers = _buildMarkers(places);
          _fitBounds(markers);
          return GoogleMap(
            initialCameraPosition: _initPos,
            markers: markers,
            polylines: _polylines,
            onMapCreated: (c) => _map = c,
            myLocationButtonEnabled: false,
            onTap: _handleMapTap, // Day2: 任意點擊地圖加入自訂景點
          );
        },
      ),
    );
  }

  /// Day2: 點地圖任意位置，彈出文字框輸入景點名稱後加入
  Future<void> _handleMapTap(LatLng pos) async {
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
                    decoration:
                        const InputDecoration(labelText: '景點名稱'),
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
      await ref.read(tripRepoProvider).addPlace(
        widget.tripId,
        Place(
          id: '_tmp',
          name: nameCtrl.text.trim(),
          lat: pos.latitude,
          lng: pos.longitude,
          order: DateTime.now().millisecondsSinceEpoch,
          stayHours: 1,
          note: '',
        ),
      );
    }
  }

  Widget _buildSidePanel(
    BuildContext context,
    List<Place> places,
    AsyncValue<List<String>> pendingAsync,
    TripRepository repo,
  ) {
    // 保留 Day1 side panel 原始實作
    if (_modes.length != max(0, places.length - 1)) {
      _modes = List.filled(max(0, places.length - 1), 'driving');
    }
    final departureTimes = <DateTime>[];
    var now = DateTime.now();
    departureTimes.add(now);
    for (var i = 0; i < places.length - 1; i++) {
      final durMin =
          int.tryParse(_durationsMap[places[i + 1].id] ?? '0') ?? 0;
      now = now
          .add(Duration(minutes: durMin))
          .add(Duration(hours: places[i].stayHours));
      departureTimes.add(now);
    }

    return Column(
      children: [
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
              for (var i = 0; i < places.length; i++)
                ListTile(
                  key: ValueKey(places[i].id),
                  title: Text('${i + 1}. ${places[i].name}'),
                  subtitle: Text(
                      '離開時間: ${DateFormat('HH:mm').format(departureTimes[i])}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () =>
                        repo.deletePlace(widget.tripId, places[i].id),
                  ),
                ),
            ],
          ),
        ),
        if (places.length > 1)
          Column(
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('各路段交通方式'),
              ),
              for (var i = 0; i < places.length - 1; i++)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                          '段 ${i + 1}: ${places[i].name} → ${places[i + 1].name}'),
                    ),
                    DropdownButton<String>(
                      value: _modes[i],
                      items: const [
                        DropdownMenuItem(
                            value: 'driving', child: Text('開車')),
                        DropdownMenuItem(
                            value: 'walking', child: Text('走路')),
                        DropdownMenuItem(value: 'bus', child: Text('公車')),
                        DropdownMenuItem(
                            value: 'subway', child: Text('捷運')),
                      ],
                      onChanged: (v) => setState(() => _modes[i] = v!),
                    ),
                  ],
                ),
            ],
          ),
        ElevatedButton.icon(
          onPressed: () => _recalculateRouteWithModes(places),
          icon: const Icon(Icons.sync),
          label: const Text('重算路線'),
        ),
        const Divider(),
        pendingAsync.when(
          data: (invites) {
            if (invites.isEmpty) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    invites.map((e) => Text('• $e')).toList(),
              ),
            );
          },
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error: $e'),
        ),
        const Divider(),
        OverflowBar(
          spacing: 8,
          overflowSpacing: 8,
          alignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              onPressed: () =>
                  _addPlaceDialog(context, ref.read(tripRepoProvider)),
              icon: const Icon(Icons.add_location_alt_outlined),
              label: const Text('新增景點'),
            ),
            OutlinedButton.icon(
              onPressed: () => showDialog(
                context: context,
                builder: (_) =>
                    AddInviteDialog(tripId: widget.tripId),
              ),
              icon: const Icon(Icons.mail_outlined),
              label: const Text('邀請成員'),
            ),
            ElevatedButton.icon(
              onPressed: () =>
                  context.push('/trip/${widget.tripId}/expense'),
              icon: const Icon(Icons.receipt_long),
              label: const Text('帳單'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  context.push('/trip/${widget.tripId}/chat'),
              icon: const Icon(Icons.chat_bubble_outline),
              label: const Text('聊天室'),
            ),
          ],
        ),
      ],
    );
  }

  Future<void> _recalculateRouteWithModes(List<Place> places) async {
    final key = const String.fromEnvironment('PLACES_API_KEY');
    final service = ScheduleService(key);
    final segments = <SegmentInfo>[];
    for (var i = 0; i < places.length - 1; i++) {
      segments.add(await service.getSegmentInfo(
        '${places[i].lat},${places[i].lng}',
        '${places[i + 1].lat},${places[i + 1].lng}',
        _modes[i],
      ));
    }
    final allPoints = <LatLng>[];
    final decoder = PolylinePoints();
    for (final seg in segments) {
      allPoints.addAll(
        decoder.decodePolyline(seg.polyline).map(
          (p) => LatLng(p.latitude, p.longitude),
        ),
      );
    }
    setState(() {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: allPoints,
          width: 4,
        ),
      };
      _durationsMap = {
        for (var i = 0; i < segments.length; i++)
          places[i + 1].id:
              (segments[i].duration / 60).round().toString(),
      };
    });
  }

  Future<void> _addPlaceDialog(
      BuildContext context, TripRepository repo) async {
    final query = TextEditingController();
    List<PlaceSuggestion>? results;
    PlaceSuggestion? chosen;
    await showDialog<PlaceSuggestion?>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('搜尋景點'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: query,
                decoration:
                    const InputDecoration(hintText: '輸入關鍵字'),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () async {
                  final key =
                      const String.fromEnvironment('PLACES_API_KEY');
                  if (key.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text('請設定 PLACES_API_KEY')),
                    );
                    return;
                  }
                  results = await PlaceSearchService(key)
                      .search(query.text);
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
                        Navigator.pop(ctx, chosen);
                      },
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) {
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

  Set<Marker> _buildMarkers(List<Place> places) => {
        for (var i = 0; i < places.length; i++)
          Marker(
            markerId: MarkerId(places[i].id),
            position: LatLng(places[i].lat, places[i].lng),
            infoWindow:
                InfoWindow(title: '${i + 1}. ${places[i].name}'),
          ),
      };

  void _fitBounds(Set<Marker> markers) {
    if (_map == null || markers.isEmpty) return;
    final lats = markers.map((m) => m.position.latitude);
    final lngs = markers.map((m) => m.position.longitude);
    final sw = LatLng(lats.reduce(min), lngs.reduce(min));
    final ne = LatLng(lats.reduce(max), lngs.reduce(max));
    _map!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        48,
      ),
    );
  }
}
