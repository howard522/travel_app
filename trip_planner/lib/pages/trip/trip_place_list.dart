import 'package:flutter/material.dart';
import 'package:reorderables/reorderables.dart';
import 'package:intl/intl.dart';

import '../../models/place.dart';

/// TripPlaceList: 列出單日景點，可拖曳排序、刪除、停留時數
class TripPlaceList extends StatelessWidget {
  final List<Place> places;
  final List<DateTime> departureTimes;
  final void Function(int oldIdx, int newIdx) onReorder;
  final void Function(Place p) onDelete;
  final void Function(Place p, int newHours) onStayHoursChanged;

  const TripPlaceList({
    Key? key,
    required this.places,
    required this.departureTimes,
    required this.onReorder,
    required this.onDelete,
    required this.onStayHoursChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ReorderableColumn(
      crossAxisAlignment: CrossAxisAlignment.start,
      onReorder: onReorder,
      children: [
        for (var i = 0; i < places.length; i++)
          Card(
            key: ValueKey(places[i].id),
            margin: const EdgeInsets.symmetric(vertical: 4),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${i + 1}. ${places[i].name}',
                      style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 4),
                  Text(
                      '抵達: ${DateFormat('HH:mm').format(departureTimes[i])}'),
                  Row(
                    children: [
                      const Text('停留 (小時):'),
                      const SizedBox(width: 8),
                      DropdownButton<int>(
                        value: places[i].stayHours,
                        items: List.generate(12, (j) => j + 1)
                            .map((h) => DropdownMenuItem(
                                  value: h,
                                  child: Text('$h'),
                                ))
                            .toList(),
                        onChanged: (h) {
                          if (h != null) onStayHoursChanged(places[i], h);
                        },
                      ),
                    ],
                  ),
                  Text(
                      '離開: ${DateFormat('HH:mm').format(departureTimes[i].add(Duration(hours: places[i].stayHours)))}'),
                  Align(
                    alignment: Alignment.topRight,
                    child: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () => onDelete(places[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
