import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import 'dart:math';

class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key});

  Future<List<List<dynamic>>> loadStops() async {
    final file = await rootBundle.loadString('assets/csv/stops.txt');
    final lines = file.split('\n');
    lines.removeAt(0); // Remove header
    return const CsvToListConverter().convert(lines.join('\n'));
  }

  Future<Map<String, String>> loadRouteShortNames() async {
  final file = await rootBundle.loadString('assets/csv/routes.txt');
  final lines = file.split('\n');
  lines.removeAt(0); // Remove header

  final Map<String, String> routeMap = {};
  for (final line in lines) {
    final fields = line.split(',');
    if (fields.length > 2) {
      routeMap[fields[0]] = fields[2]; // Map route_id to route_short_name
    }
  }
  return routeMap;
}

  Future<List<Map<String, dynamic>>> fetchNextDepartures(String stopId, Map<String, String> routeMap) async {
  // Fetch next departures for the stop
  final response = await http.get(Uri.parse('http://localhost:8081/stops/$stopId/next'));
  print(stopId);

  if (response.statusCode == 200) {
    final List<dynamic> rawData = jsonDecode(response.body);

    // Map to fetch the required data
    return await Future.wait(rawData.map((entry) async {
      // Extract trip_id
      final tripId = entry["trip_id"]["String"];

      // Fetch trip details from /trips/:tripid
      final tripResponse = await http.get(Uri.parse('http://localhost:8081/trips/$tripId'));
      if (tripResponse.statusCode != 200) {
        throw Exception('Failed to fetch trip details for trip: $tripId');
      }

      // Parse trip details
      final tripData = jsonDecode(tripResponse.body);
      final routeId = tripData["route_id"]["String"]; // Extract route_id

      return {
        "trip_id": tripId,
        "arrival_time": entry["arrival_time"]["String"],
        "departure_time": entry["departure_time"]["String"],
        "stop_headsign": entry["stop_headsign"]["String"],
        "stop_sequence": entry["stop_sequence"]["Int32"],
        "pickup_type": entry["pickup_type"]["Int32"],
        "drop_off_type": entry["drop_off_type"]["Int32"],
        "time_point": entry["time_point"]["Int32"],
        "route_short_name": routeMap[routeId] ?? "Unknown", // Map route_id to route_short_name
      };
    }).toList());
  } else {
    throw Exception('Failed to fetch next departures for stop: $stopId');
  }
}


  Future<List<ListTile>> parseStops(
    AsyncSnapshot<Position> snapshot, List<Map<String, dynamic>> routes) async {
  final stops = await loadStops();
  final routeMap = await loadRouteShortNames(); // Load route_short_name mapping
  final Position userLocation = snapshot.data!;

  // Find 8 nearest stops
  List<Map<String, dynamic>> nearestStops = [];
  List<double> distances = [];

  for (List<dynamic> stop in stops) {
    final double distance = Geolocator.distanceBetween(
        userLocation.latitude, userLocation.longitude, stop[4], stop[5]);
    if (nearestStops.length < 8) {
      nearestStops.add({
        "stop_id": stop[0],
        "stop_name": stop[2],
        "latitude": stop[4],
        "longitude": stop[5],
        "distance": distance,
      });
      distances.add(distance);
    } else {
      double maxDistance = distances.reduce(max);
      int maxIndex = distances.indexOf(maxDistance);
      if (distance < maxDistance) {
        nearestStops[maxIndex] = {
          "stop_id": stop[0],
          "stop_name": stop[2],
          "latitude": stop[4],
          "longitude": stop[5],
          "distance": distance,
        };
        distances[maxIndex] = distance;
      }
    }
  }

  // Sort stops by distance
  nearestStops.sort((a, b) => a["distance"].compareTo(b["distance"]));

  // Generate stop tiles with next bus info
  List<ListTile> stopTiles = await Future.wait(nearestStops.map((stop) async {
    final nextDepartures = await fetchNextDepartures(stop["stop_id"], routeMap);

    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(child: Text(stop["stop_name"])),
          ),
          Expanded(
            child: Center(child: Text('${stop["distance"].toStringAsFixed(0)} m')),
          ),
          Expanded(
            child: Center(
              child: nextDepartures.isNotEmpty
                  ? Text(
                      '${nextDepartures[0]["route_short_name"]} in ${_calculateMinutesToArrival(nextDepartures[0]["arrival_time"])} min')
                  : const Text('No buses'),
            ),
          ),
        ],
      ),
    );
  }).toList());

  // Add header
  stopTiles.insert(
    0,
    const ListTile(
      title: Row(
        children: [
          Expanded(
            child: Center(
              child: Text('Stop Name', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Center(
              child: Text('Distance', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          Expanded(
            child: Center(
              child: Text('Next Bus', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    ),
  );

  return stopTiles;
}

/// Helper function to calculate minutes to arrival
int _calculateMinutesToArrival(String arrivalTime) {
  if (arrivalTime.isEmpty) return 0;

  final now = DateTime.now();

  // Parse the arrivalTime string, ignoring the date part
  final arrivalParts = arrivalTime.split('T');
  final arrivalTimeOnly = arrivalParts[1].replaceAll('Z', '');

  final arrivalDateTime = DateTime(
    now.year,
    now.month,
    now.day,
    int.parse(arrivalTimeOnly.split(':')[0]), // Hours
    int.parse(arrivalTimeOnly.split(':')[1]), // Minutes
    int.parse(arrivalTimeOnly.split(':')[2]), // Seconds
  );

  // Calculate the difference in minutes
  final difference = arrivalDateTime.difference(now).inMinutes;

  return difference > 0 ? difference : 0; // Return 0 if time is in the past
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
            future: parseStops(snapshot, []), // Routes can be passed if needed
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
