import 'package:better_tfi/widgets/next_arrivals_display.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../pages/real_time_info_page.dart' as rti;

class SearchResultDisplay extends StatelessWidget {
  final String searchQuery;
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const SearchResultDisplay({super.key, required this.searchQuery, required this.apiBaseUrl1, required this.apiBaseUrl2});

  Future<List<ListTile>> parseStops(BuildContext context, String searchQuery) async {
    final response = await http.get(Uri.parse('$apiBaseUrl2/stops?query=$searchQuery'));

    if (response.body == 'null') {
      return [
        const ListTile(
          title: Center(child: Text('No Search Results')),
        )
      ];
    }

    List<Map<String, dynamic>> stops = [];

    if (response.statusCode == 200) {
      final List<dynamic> rawData = jsonDecode(response.body);
      stops = rawData.map<Map<String, dynamic>>((stop) {
        return {
          "stop_id": stop["stop_id"]["String"],
          "stop_name": stop["stop_name"]["String"],
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
      throw Exception("Failed to fetch stops");
    }

    List<ListTile> stopTiles = await Future.wait(stops.map((stop) async {
      final nextDepartures = stop["trips"];
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Adjust padding if needed
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
      future: parseStops(context, searchQuery),
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