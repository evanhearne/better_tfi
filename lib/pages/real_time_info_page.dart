import 'package:better_tfi/widgets/search_result_display.dart';
import 'package:flutter/material.dart';
import '../widgets/location_display.dart';

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

class RealTimeInfoPage extends StatefulWidget {
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const RealTimeInfoPage({super.key, required this.apiBaseUrl1, required this.apiBaseUrl2});

  @override
  RealTimeInfoPageState createState() => RealTimeInfoPageState();
}

class RealTimeInfoPageState extends State<RealTimeInfoPage> {
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
                  _searchQuery = value.replaceAll('’', '\''); // single quote filter bug fix
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
