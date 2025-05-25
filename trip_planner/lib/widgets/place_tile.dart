import 'package:flutter/material.dart';
import '../models/place.dart';

class PlaceTile extends StatelessWidget {
  const PlaceTile({Key? key, required this.place}) : super(key: key);
  final Place place;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: key, // ReorderableListView 需要
      leading: const Icon(Icons.place),
      title: Text(place.name),
      subtitle: Text(place.address ?? ''),
      trailing: const Icon(Icons.drag_handle),
    );
  }
}
