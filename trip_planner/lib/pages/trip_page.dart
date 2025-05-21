import 'package:flutter/material.dart';

class TripPage extends StatelessWidget {
  const TripPage({super.key, required this.tripId});
  final String tripId;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: Text('Trip $tripId')),
        body: const Center(child: Text('TripPage')),
      );
}
