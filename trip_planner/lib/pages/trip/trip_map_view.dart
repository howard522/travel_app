import 'dart:math';

import 'package:flutter/foundation.dart'; // for Factory
import 'package:flutter/gestures.dart';   // for EagerGestureRecognizer
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';

import '../../models/place.dart';
import '../../models/segment_info.dart';
import '../../services/schedule_service.dart';
import '../../models/trip.dart';

/// TripMapView: 單一天的地圖畫面，啟動時如果當天有景點就自動對焦到所有標記，
/// 否則保持預設的「台灣中央」位置。
class TripMapView extends ConsumerStatefulWidget {
  final Trip trip;
  final DateTime day;
  final AsyncValue<List<Place>> placesAsync;
  final Future<void> Function(LatLng pos) onMapTap;

  const TripMapView({
    Key? key,
    required this.trip,
    required this.day,
    required this.placesAsync,
    required this.onMapTap,
  }) : super(key: key);

  @override
  ConsumerState<TripMapView> createState() => _TripMapViewState();
}

class _TripMapViewState extends ConsumerState<TripMapView> {
  GoogleMapController? _mapController;
  Set<Polyline> _polylines = {};
  Map<String, String> _durationsMap = {};
  List<String> _modes = [];

  /// 預設鏡頭：台灣本島中央
  static const CameraPosition _taiwanCenter = CameraPosition(
    target: LatLng(23.5, 121.0),
    zoom: 6.5,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.placesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading places: $e')),
      data: (allPlaces) {
        // 過濾出當天的 places
        final dayPlaces = allPlaces
            .where((p) =>
                p.date.year == widget.day.year &&
                p.date.month == widget.day.month &&
                p.date.day == widget.day.day)
            .toList()
          ..sort((a, b) => a.order.compareTo(b.order));

        // 建立所有 Marker
        final markers = <Marker>{
          for (var i = 0; i < dayPlaces.length; i++)
            Marker(
              markerId: MarkerId(dayPlaces[i].id),
              position: LatLng(dayPlaces[i].lat, dayPlaces[i].lng),
              infoWindow: InfoWindow(title: '${i + 1}. ${dayPlaces[i].name}'),
            ),
        };

        return GoogleMap(
          initialCameraPosition: _taiwanCenter,
          markers: markers,
          polylines: _polylines,
          onMapCreated: (controller) {
            _mapController = controller;
            // 當地圖建好以後，如果當天有景點，就做一次 fitBounds
            if (dayPlaces.isNotEmpty) {
              _fitBounds(markers);
            }
          },
          myLocationButtonEnabled: false,
          onTap: widget.onMapTap,
          // 讓地圖優先接管所有拖曳/縮放手勢，隔離與 TabBarView 的衝突
          gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
            Factory<OneSequenceGestureRecognizer>(
              () => EagerGestureRecognizer(),
            ),
          },
        );
      },
    );
  }

  /// 對所有標記做 Bounds，並通知地圖做動畫
  void _fitBounds(Set<Marker> markers) {
    if (_mapController == null || markers.isEmpty) return;
    final lats = markers.map((m) => m.position.latitude);
    final lngs = markers.map((m) => m.position.longitude);
    final sw = LatLng(lats.reduce(min), lngs.reduce(min));
    final ne = LatLng(lats.reduce(max), lngs.reduce(max));
    _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: sw, northeast: ne),
        48, // padding
      ),
    );
  }

  /// 如果需要讓外層呼叫「重算路線」，可用 GlobalKey 或 Provider 連結此方法
  Future<void> recalcRoute(List<Place> dayPlaces, List<String> modes) async {
    final key = const String.fromEnvironment('ROUTES_API_KEY');
    final service = ScheduleService(key);
    final segments = <SegmentInfo>[];

    for (var i = 0; i < dayPlaces.length - 1; i++) {
      segments.add(await service.getSegmentInfo(
        '${dayPlaces[i].lat},${dayPlaces[i].lng}',
        '${dayPlaces[i + 1].lat},${dayPlaces[i + 1].lng}',
        modes[i],
      ));
    }

    final allPoints = <LatLng>[];
    final decoder = PolylinePoints();
    for (final seg in segments) {
      allPoints.addAll(decoder.decodePolyline(seg.polyline).map(
        (p) => LatLng(p.latitude, p.longitude),
      ));
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
          dayPlaces[i + 1].id: (segments[i].duration / 60).round().toString(),
      };
      _modes = List.from(modes);
    });
  }
}
