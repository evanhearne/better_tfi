import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../pages/real_time_info_page.dart' as rti;

class SearchResultDisplay extends StatelessWidget {
  final String searchQuery;

  const SearchResultDisplay({super.key, required this.searchQuery});

  Future<List<ListTile>> parseStops(String searchQuery) async {
    final routeResponse = await http.get(Uri.parse('http://localhost:8081/routes'));
    
    Map<String,String> routeMap = {};
    
    if (routeResponse.statusCode == 200) {
      final List<dynamic> rawData = jsonDecode(routeResponse.body);
      for (var route in rawData) {
        routeMap[route["route_id"]["String"]] = route["route_short_name"]["String"];
      }
    }

    // Fetch GTFS-RT Data
    final gtfsData = await rti.fetchGtfsData(); // Fetch GTFS-RT data

    // use API to get stops --> localhost:8081/stops
    final response = await http.get(Uri.parse('http://localhost:8081/stops?query=${searchQuery}'));

    if (response.body == 'null') {
      return [
        const ListTile(
          title: Center(child: Text('No Search Results')),
        )
      ];
    }

    // parse query to usuable format
    List<Map<String, dynamic>> stops = [];

    if (response.statusCode == 200) {
      final List<dynamic> rawData = jsonDecode(response.body);
      stops = rawData.map<Map<String, dynamic>>((stop) {
        return {
          "stop_id": stop["stop_id"]["String"],
          "stop_name": stop["stop_name"]["String"],
        };
      }).toList();
    } else {
      throw Exception("Failed to fetch stops");
    }

    // Generate stop tiles
    List<ListTile> stopTiles = await Future.wait(stops.map((stop) async {
      final nextDepartures = await rti.fetchNextDepartures(stop["stop_id"], routeMap, gtfsData);
      return ListTile(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Center(child: Text(stop["stop_name"]))
            ),
            Expanded(child: Center(
              child: nextDepartures.isNotEmpty
                  ? Text(
                      '${nextDepartures[0]["route_short_name"]} in ${rti.calculateMinutesToArrival(nextDepartures[0]["arrival_time"])} min')
                  : const Text('No buses'),
            )),
          ],
        )
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
      future: parseStops(searchQuery), // Replace 'searchQuery' with the actual query
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No stops found'));
        } else {
          return ListView(
            children: snapshot.data!,
          );
        }
      },
    );
  }

}