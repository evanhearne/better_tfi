import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Position>(
      future: Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 10,
        ),
      ),
      builder: (BuildContext context, AsyncSnapshot<Position> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          final position = snapshot.data!;
          return Text('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
        } else {
          return const Text('No location data available');
        }
      },
    );
  }
}
