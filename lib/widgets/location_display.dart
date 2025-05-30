import 'dart:async';

import 'package:better_tfi/widgets/next_arrivals_display.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../pages/real_time_info_page.dart' as rti;

class LocationDisplay extends StatefulWidget {
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const LocationDisplay({super.key, required this.apiBaseUrl1, required this.apiBaseUrl2});

  @override
  LocationDisplayState createState() => LocationDisplayState();
}

class LocationDisplayState extends State<LocationDisplay> {

  late Timer _timer;
  late Position _cachedPosition;
  late Future<List<ListTile>> _stopTilesFuture;

  @override
  void initState() {
    super.initState();
    // Kick off the very first fetch (position + stops)
    _stopTilesFuture = _fetchStopsOnce();
    // And then every 15s just re-use the cached position…
    _timer = Timer.periodic(const Duration(seconds: 15), (_) {
      setState(() {
        _stopTilesFuture = parseStops(_cachedPosition);
      });
    });
  }

  Future<List<ListTile>> _fetchStopsOnce() async {
    // get and cache the position
    _cachedPosition = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.best,
        distanceFilter: 10,
      ),
    );
    // fetch stops for it
    return parseStops(_cachedPosition);
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  Future<List<ListTile>> parseStops(Position _cachedPosition) async {
    final Position userLocation = _cachedPosition;

    final response = await http.get(Uri.parse('${widget.apiBaseUrl2}/nearestStops?lat=${userLocation.latitude}&lng=${userLocation.longitude}'));
    List<Map<String, dynamic>> nearestStops = [];

    if (response.statusCode == 200) {
      final List<dynamic> rawData = jsonDecode(response.body);
      nearestStops = rawData.map<Map<String, dynamic>>((stop) {
        return {
          "stop_id": stop["stop_id"]["String"],
          "stop_name": stop["stop_name"]["String"],
          "latitude": stop["latitude"]["Float64"],
          "longitude": stop["longitude"]["Float64"],
          "distance": stop["distance"],
          "trips": stop["trips"].map<Map<String, dynamic>>((trip){
            return {
               "arrival_time": trip["arrival_time"]["String"],
              "departure_time": trip["departure_time"]["String"],
              "drop_off_type": trip["drop_off_type"]["Int32"],
              "pickup_type": trip["pickup_type"]["Int32"],
              "route_short_name": trip["route_short_name"]["String"],
              "stop_headsign": trip["stop_headsign"]["String"],
              "stop_sequence": trip["stop_sequence"]["Int32"],
              "time_point": trip["time_point"]["Int32"],
              "trip_id": trip["trip_id"]["String"],
              };
          }).toList()
        };
      }).toList();
    } else {
      throw Exception('Failed to fetch nearest stops');
    }

    List<ListTile> stopTiles = await Future.wait(nearestStops.map((stop) async {
      final nextDepartures = stop["trips"];
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2), // Adjust padding if needed
        title: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NextArrivalsDisplay(
                    stopName: stop["stop_name"],
                    nextDepartures: nextDepartures,
                  ),
                ),
              );
            },
            borderRadius: BorderRadius.circular(10), // Ensures ripple effect follows the card's shape
            child: Padding(
              padding: const EdgeInsets.all(10), // Add padding inside the card
              child: Row(
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
                              '${nextDepartures[0]["route_short_name"]} in ${rti.calculateMinutesToArrival(nextDepartures[0]["arrival_time"])} min')
                          : const Text('No buses'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }).toList());

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

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<ListTile>>(
      future: _stopTilesFuture,
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final tiles = snap.data!;
        return ListView(children: tiles);
      },
    );
  }
}
