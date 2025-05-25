import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/trip.dart';
import '../models/place.dart';
import '../widgets/place_tile.dart';
import '../providers/trip_repo_provider.dart';

class TripPage extends ConsumerStatefulWidget {
  /// router 一定會帶的行程 id
  final String tripId;

  /// 可選：上一頁已帶過 Trip 時可省一次讀取
  final Trip? trip;

  const TripPage({
    Key? key,
    required this.tripId,
    this.trip,
  }) : super(key: key);

  @override
  ConsumerState<TripPage> createState() => _TripPageState();
}

class _TripPageState extends ConsumerState<TripPage> {
  late final String _id;
  Trip? _trip;
  List<Place> _places = [];
  StreamSubscription<List<Place>>? _sub;

  @override
  void initState() {
    super.initState();
    _id = widget.trip?.id ?? widget.tripId;
    _trip = widget.trip;
    _fetchTripIfNeeded();
    _sub = ref
        .read(tripRepoProvider)
        .watchPlaces(_id)
        .listen((places) => setState(() => _places = places));
  }

  Future<void> _fetchTripIfNeeded() async {
    if (_trip != null) return;
    _trip = await ref.read(tripRepoProvider).getTrip(_id);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (_trip == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(_trip!.title)),
      body: ReorderableListView.builder(
        itemCount: _places.length,
        onReorder: _onReorder,
        itemBuilder: (_, index) => PlaceTile(
          key: ValueKey(_places[index].id),
          place: _places[index],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openSearch,
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    setState(() {
      final item = _places.removeAt(oldIndex);
      _places.insert(newIndex, item);
    });
    await ref
        .read(tripRepoProvider)
        .updatePlacesOrder(_id, _places);
  }

  void _openSearch() {
    Navigator.pushNamed(context, '/search', arguments: _id);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
