import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:csv/csv.dart';
import '../proto/gtfs-realtime.pb.dart' as gtfs;
import 'dart:math';

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

  Future<List<Map<String, dynamic>>> loadRoutes() async {
    final file = await rootBundle.loadString('assets/csv/routes.txt');
    final lines = file.split('\n');
    lines.removeAt(0); // Remove header
    // drop the last line
    lines.removeLast();

    final List<Map<String, dynamic>> routes = lines.map((line) {
      final fields = line.split(',');
      return {
        "route_id": fields[0],
        "route_short_name": fields[2],
        "route_long_name": fields[3],
      };
    }).toList();

    return routes;
  }

  Future<List<List<dynamic>>> loadStops() async {
    final file = await rootBundle.loadString('assets/csv/stops.txt');
    final lines = file.split('\n');
    lines.removeAt(0); // Remove header
    return const CsvToListConverter().convert(lines.join('\n'));
  }

  Future<List<ListTile>> parseStops(
      AsyncSnapshot<Position> snapshot, gtfs.FeedMessage feedMessage, List<Map<String, dynamic>> routes) async {
    // Load stops.txt
    final stops = await loadStops();

    final Position userLocation = snapshot.data!;

    // Find 8 nearest stops
    List<List<dynamic>> nearestStops = [];
    List<double> distances = [];

    for (List<dynamic> stop in stops) {
      final double distance = Geolocator.distanceBetween(
          userLocation.latitude, userLocation.longitude, stop[4], stop[5]);
      if (nearestStops.length < 8) {
        nearestStops.add(stop);
        distances.add(distance);
      } else {
        double maxDistance = distances.reduce(max);
        int maxIndex = distances.indexOf(maxDistance);
        if (distance < maxDistance) {
          nearestStops[maxIndex] = stop;
          distances[maxIndex] = distance;
        }
      }
    }

    // Sort stops by distance
    List<int> sortedIndices = List.generate(nearestStops.length, (index) => index);
    sortedIndices.sort((a, b) => distances[a].compareTo(distances[b]));

    // Generate stop tiles with next bus info
    List<ListTile> stopTiles = sortedIndices.map((index) {
      final stopId = nearestStops[index][0];
      final nextBus = _findNextBus(feedMessage, stopId, routes);

      return ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(child: Text(nearestStops[index][2])),
            ),
            Expanded(
              child: Center(child: Text('${distances[index].toStringAsFixed(0)} m')),
            ),
            Expanded(
              child: Center(
                child: nextBus != null
                    ? Text(
                        '${nextBus["route_short_name"]} in ${nextBus["minutes_to_arrival"]} min')
                    : const Text('No buses'),
              ),
            ),
          ],
        ),
      );
    }).toList();

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

  Map<String, dynamic>? _findNextBus(gtfs.FeedMessage feedMessage, String stopId, List<Map<String, dynamic>> routes) {
    final now = DateTime.now();
    Map<String, dynamic>? nextBus;

    for (var entity in feedMessage.entity) {
      for (var stopUpdate in entity.tripUpdate.stopTimeUpdate) {
        if (stopUpdate.stopId.toString() == stopId.toString()) {
          final delaySeconds = stopUpdate.arrival.hasDelay() ? stopUpdate.arrival.delay : 0;

          // Parse trip start time and date
          final startTimeParts = entity.tripUpdate.trip.startTime.split(':');
          final startDate = entity.tripUpdate.trip.startDate;
          final tripStartTime = DateTime(
            int.parse(startDate.substring(0, 4)),
            int.parse(startDate.substring(4, 6)),
            int.parse(startDate.substring(6, 8)),
            int.parse(startTimeParts[0]),
            int.parse(startTimeParts[1]),
            int.parse(startTimeParts[2]),
          );

          // Calculate scheduled arrival time
          final scheduledArrival = tripStartTime.add(
            Duration(seconds: stopUpdate.arrival.time.toInt() + delaySeconds),
          );

          if (scheduledArrival.isAfter(now)) {
            final minutesToArrival =
                scheduledArrival.difference(now).inMinutes;

            if (nextBus == null || minutesToArrival < nextBus["minutes_to_arrival"]) {
              final route = routes.firstWhere(
                (r) => r["route_id"] == entity.tripUpdate.trip.routeId,
                orElse: () => <String, String>{"route_short_name": "Unknown", "route_long_name": "Unknown"},
              );
              nextBus = {
                "route_short_name": route["route_short_name"],
                "route_long_name": route["route_long_name"],
                "minutes_to_arrival": minutesToArrival
              };
            }
          }
        }
      }
    }

    return nextBus;
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
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: loadRoutes(),
            builder: (BuildContext context, AsyncSnapshot<List<Map<String, dynamic>>> routesSnapshot) {
              if (routesSnapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              } else if (routesSnapshot.hasError) {
                return Text('Error: ${routesSnapshot.error}');
              } else if (routesSnapshot.hasData) {
                return FutureBuilder<List<ListTile>>(
                  future: fetchGtfsData().then((feedMessage) => parseStops(snapshot, feedMessage, routesSnapshot.data!)),
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
                return const Text('No route data available');
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
