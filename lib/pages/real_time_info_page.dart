import 'package:better_tfi/widgets/search_result_display.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../widgets/location_display.dart';
import '../proto/gtfs-realtime.pb.dart' as gtfs;
import 'dart:convert';

/// Helper function to calculate minutes to arrival
int calculateMinutesToArrival(String arrivalTime) {
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

Future<gtfs.FeedMessage> fetchGtfsData(String apiBaseUrl1) async {
  final response = await http.get(Uri.parse('$apiBaseUrl1/gtfsr'));

  if (response.statusCode == 200) {
    return gtfs.FeedMessage.fromBuffer(response.bodyBytes);
  } else {
    throw Exception('Failed to load GTFS data');
  }
}

Future<List<Map<String, dynamic>>> fetchNextDepartures(
    String stopId, Map<String, String> routeMap, gtfs.FeedMessage feedMessage, String apiBaseUrl2) async {
  // Fetch next departures for the stop
  final response = await http.get(Uri.parse('$apiBaseUrl2/stops/$stopId/next'));

  if (response.statusCode == 200 && response.body != "null") {
    final List<dynamic> rawData = jsonDecode(response.body);

    // Map to fetch the required data
    return await Future.wait(rawData.map((entry) async {
      final tripId = entry["trip_id"]["String"];

      // Fetch trip details from /trips/:tripid
      final tripResponse = await http.get(Uri.parse('$apiBaseUrl2/trips/$tripId'));
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

class RealTimeInfoPage extends StatefulWidget {
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const RealTimeInfoPage({super.key, required this.apiBaseUrl1, required this.apiBaseUrl2});

  @override
  _RealTimeInfoPageState createState() => _RealTimeInfoPageState();
}

class _RealTimeInfoPageState extends State<RealTimeInfoPage> {
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 32.0, left: 16.0, right: 16.0),
            child: SearchBar(
              hintText: 'Search for a bus stop...',
              trailing: const [Icon(Icons.search)],
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: _searchQuery.isEmpty
                  ? LocationDisplay(apiBaseUrl1: widget.apiBaseUrl1, apiBaseUrl2: widget.apiBaseUrl2)
                  : SearchResultDisplay(searchQuery: _searchQuery, apiBaseUrl1: widget.apiBaseUrl1, apiBaseUrl2: widget.apiBaseUrl2),
            ),
          ),
        ],
      ),
    );
  }
}
