import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:csv/csv.dart';

class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key});

  Future<List<ListTile>> parseStops(AsyncSnapshot<Position> snapshot) async {
    // specify path to txt file
    final file = await rootBundle.loadString('assets/csv/stops.txt');
    // read lines
    final lines = file.split('\n');
    // remove the first line
    lines.removeAt(0);
    // process lines to find stop nearest to user
    // get user location
    final Position userLocation = snapshot.data!;
    final List<List<dynamic>> stops = const CsvToListConverter().convert(lines.join('\n'));
    // find 8 nearest stops
    List<List<dynamic>> nearestStops = [];
    List<double> distances = [];

    for (List<dynamic> stop in stops) {
      final double distance = Geolocator.distanceBetween(userLocation.latitude, userLocation.longitude, stop[4], stop[5]);
      if (nearestStops.length < 8) {
        nearestStops.add(stop);
        distances.add(distance);
      } else {
        double maxDistance = distances.reduce((a, b) => a > b ? a : b);
        int maxIndex = distances.indexOf(maxDistance);
        if (distance < maxDistance) {
          nearestStops[maxIndex] = stop;
          distances[maxIndex] = distance;
        }
      }
    }

    // sort stops by distance
    List<int> sortedIndices = List.generate(nearestStops.length, (index) => index);
    sortedIndices.sort((a, b) => distances[a].compareTo(distances[b]));

    // return stop names in ListTile widgets
    List<ListTile> stopTiles = sortedIndices.map((index) {
      return ListTile(
        title: Text(nearestStops[index][2]),
        subtitle: Text('Distance: ${distances[index].toStringAsFixed(2)} meters'),
      );
    }).toList();

    return stopTiles;
  }

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
          return FutureBuilder<List<ListTile>>(
            future: parseStops(snapshot),
            builder: (BuildContext context, AsyncSnapshot<List<ListTile>> listTileSnapshot) {
              if (listTileSnapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (listTileSnapshot.hasError) {
                return Text('Error: ${listTileSnapshot.error}');
              } else if (listTileSnapshot.hasData) {
                return ListView(
                  children: listTileSnapshot.data!,
                );
              } else {
                return const Text('No stop data available');
              }
            },
          );
        } else {
          return const Text('No location data available');
        }
      },
    );
  }
}
