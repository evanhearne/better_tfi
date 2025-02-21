import 'package:flutter/material.dart';
import '../widgets/location_display.dart';

class RealTimeInfoPage extends StatefulWidget {
  const RealTimeInfoPage({super.key});

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
                  ? const LocationDisplay()
                  : Container(), // No content for now when search query is not empty
            ),
          ),
        ],
      ),
    );
  }
}
