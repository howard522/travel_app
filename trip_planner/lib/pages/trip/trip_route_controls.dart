import 'package:flutter/material.dart';

import '../../models/place.dart';

/// TripRouteControls: 顯示交通模式 + 重算路線按鈕
class TripRouteControls extends StatelessWidget {
  final List<Place> places;
  final List<String> modes;
  final void Function(int index, String newMode) onModeChanged;
  final VoidCallback onRecalculate;

  const TripRouteControls({
    Key? key,
    required this.places,
    required this.modes,
    required this.onModeChanged,
    required this.onRecalculate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
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
                value: modes[i],
                items: const [
                  DropdownMenuItem(value: 'driving', child: Text('開車')),
                  DropdownMenuItem(value: 'walking', child: Text('走路')),
                  DropdownMenuItem(value: 'bus', child: Text('公車')),
                  DropdownMenuItem(value: 'subway', child: Text('捷運')),
                ],
                onChanged: (v) {
                  if (v != null) onModeChanged(i, v);
                },
              ),
            ],
          ),
        ElevatedButton.icon(
          onPressed: onRecalculate,
          icon: const Icon(Icons.sync),
          label: const Text('重算路線'),
        ),
      ],
    );
  }
}
