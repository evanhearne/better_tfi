import 'package:flutter/material.dart';
import '../widgets/location_display.dart';

class RealTimeInfoPage extends StatelessWidget {
  const RealTimeInfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: 32.0, left: 16.0, right: 16.0),
          child: SearchBar(
            hintText: 'Search for a bus stop...',
            trailing: [Icon(Icons.search)],
          ),
        ),
        Padding(
          padding: EdgeInsets.all(16.0),
          child: LocationDisplay(),
        ),
      ],
    );
  }
}
