import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../pages/real_time_info_page.dart' as rti;


class LocationDisplay extends StatelessWidget {
  const LocationDisplay({super.key});

  Future<List<ListTile>> parseStops(
    AsyncSnapshot<Position> snapshot) async {
  final routeResponse = await http.get(Uri.parse('http://localhost:8081/routes'));
  Map<String,String> routeMap = {};
  if (routeResponse.statusCode == 200) {
    final List<dynamic> rawData = jsonDecode(routeResponse.body);
    for (var route in rawData) {
      routeMap[route["route_id"]["String"]] = route["route_short_name"]["String"];
    }
  }
  final gtfsData = await rti.fetchGtfsData(); // Fetch GTFS-RT data
  final Position userLocation = snapshot.data!;

  // use API to get stops --> localhost:8081/nearestStops
  final response = await http.get(Uri.parse('http://localhost:8081/nearestStops?lat=${userLocation.latitude}&lng=${userLocation.longitude}'));
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
    final nextDepartures = await rti.fetchNextDepartures(stop["stop_id"], routeMap, gtfsData);
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
                      '${nextDepartures[0]["route_short_name"]} in ${rti.calculateMinutesToArrival(nextDepartures[0]["arrival_time"])} min')
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
            future: parseStops(snapshot), // Routes can be passed if needed
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
