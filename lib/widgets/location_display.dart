import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:csv/csv.dart';
import 'dart:convert';
import '../proto/gtfs-realtime.pb.dart' as gtfs;


class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key});

  Future<gtfs.FeedMessage> fetchGtfsData() async {
  final response = await http.get(Uri.parse('http://localhost:8080/gtfsr'));

  if (response.statusCode == 200) {
    return gtfs.FeedMessage.fromBuffer(response.bodyBytes);
  } else {
    throw Exception('Failed to load GTFS data');
  }
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

  Future<List<Map<String, dynamic>>> fetchNextDepartures(
    String stopId, Map<String, String> routeMap, gtfs.FeedMessage feedMessage) async {
  // Fetch next departures for the stop
  final response = await http.get(Uri.parse('http://localhost:8081/stops/$stopId/next'));

  if (response.statusCode == 200 && response.body != "null") {
    final List<dynamic> rawData = jsonDecode(response.body);

    // Map to fetch the required data
    return await Future.wait(rawData.map((entry) async {
      final tripId = entry["trip_id"]["String"];

      // Fetch trip details from /trips/:tripid
      final tripResponse = await http.get(Uri.parse('http://localhost:8081/trips/$tripId'));
      if (tripResponse.statusCode != 200) {
        throw Exception('Failed to fetch trip details for trip: $tripId');
      }

      final tripData = jsonDecode(tripResponse.body);
      final routeId = tripData["route_id"]["String"];

      // Fetch delay from GTFS-RT feed
      final delay = _getDelayForTrip(feedMessage, tripId);

      // Adjust arrival time with delay
      final originalArrivalTime = DateTime.parse(entry["arrival_time"]["String"]);
      final adjustedArrivalTime = originalArrivalTime.add(Duration(seconds: delay));

      return {
        "trip_id": tripId,
        "arrival_time": adjustedArrivalTime.toIso8601String(),
        "departure_time": entry["departure_time"]["String"],
        "stop_headsign": entry["stop_headsign"]["String"],
        "stop_sequence": entry["stop_sequence"]["Int32"],
        "pickup_type": entry["pickup_type"]["Int32"],
        "drop_off_type": entry["drop_off_type"]["Int32"],
        "time_point": entry["time_point"]["Int32"],
        "route_short_name": routeMap[routeId] ?? "Unknown",
      };
    }).toList());
  } else if (response.statusCode == 200 && response.body == "null") {
    return [];
  } else {
    throw Exception('Failed to fetch next departures for stop: $stopId');
  }
}

/// Helper function to get delay for a trip from GTFS-RT feed
int _getDelayForTrip(gtfs.FeedMessage feedMessage, String tripId) {
  for (var entity in feedMessage.entity) {
    if (entity.hasTripUpdate() && entity.tripUpdate.trip.tripId == tripId) {
      final stopTimeUpdates = entity.tripUpdate.stopTimeUpdate;
      for (var update in stopTimeUpdates) {
        if (update.hasArrival() && update.arrival.hasDelay()) {
          return update.arrival.delay;
        }
      }
    }
  }
  return 0; // Default to no delay
}

  Future<List<ListTile>> parseStops(
    AsyncSnapshot<Position> snapshot, List<Map<String, dynamic>> routes) async {
  final routeMap = await loadRouteShortNames(); // Load route_short_name mapping
  final gtfsData = await fetchGtfsData(); // Fetch GTFS-RT data
  final Position userLocation = snapshot.data!;

  // use API to get stops --> localhost:8081/stops
  final response = await http.get(Uri.parse('http://localhost:8081/stops?lat=${userLocation.latitude}&lng=${userLocation.longitude}'));
  List<Map<String, dynamic>> nearestStops = [];

  if (response.statusCode == 200) {
    final List<dynamic> rawData = jsonDecode(response.body);
    nearestStops = rawData.map<Map<String, dynamic>>((stop) {
      return {
        "stop_id": stop["stop_id"]["String"],
        "stop_name": stop["stop_name"]["String"],
        "latitude": stop["latitude"]["String"],
        "longitude": stop["longitude"]["String"],
        "distance": stop["distance"],
      };
    }).toList();
  } else {
    throw Exception('Failed to fetch nearest stops');
  }

  // Generate stop tiles with next bus info
  List<ListTile> stopTiles = await Future.wait(nearestStops.map((stop) async {
    final nextDepartures = await fetchNextDepartures(stop["stop_id"], routeMap, gtfsData);
    return ListTile(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Center(child: Text(stop["stop_name"])),
          ),
          Expanded(
            child: Center(child: Text('${stop["distance"]} m')),
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
    int.parse(arrivalTimeOnly.split(':')[2].split('.')[0]), // Seconds
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
