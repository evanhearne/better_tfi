import 'package:better_tfi/widgets/next_arrivals_display.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import '../pages/real_time_info_page.dart' as rti;

class LocationDisplay extends StatelessWidget {
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const LocationDisplay({super.key, required this.apiBaseUrl1, required this.apiBaseUrl2});

  Future<List<ListTile>> parseStops(
    BuildContext context, AsyncSnapshot<Position> snapshot) async {
    final routeResponse = await http.get(Uri.parse('$apiBaseUrl2/routes'));
    Map<String,String> routeMap = {};
    if (routeResponse.statusCode == 200) {
      final List<dynamic> rawData = jsonDecode(routeResponse.body);
      for (var route in rawData) {
        routeMap[route["route_id"]["String"]] = route["route_short_name"]["String"];
      }
    }
    final gtfsData = await rti.fetchGtfsData(apiBaseUrl1);
    final Position userLocation = snapshot.data!;

    final response = await http.get(Uri.parse('$apiBaseUrl2/nearestStops?lat=${userLocation.latitude}&lng=${userLocation.longitude}'));
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

    List<ListTile> stopTiles = await Future.wait(nearestStops.map((stop) async {
      final nextDepartures = await rti.fetchNextDepartures(stop["stop_id"], routeMap, gtfsData, apiBaseUrl2);
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
            future: parseStops(context, snapshot), // Routes can be passed if needed
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
