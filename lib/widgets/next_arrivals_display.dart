import 'package:flutter/material.dart';
import '../pages/real_time_info_page.dart' as rti;

class NextArrivalsDisplay extends StatelessWidget {
  final String stopName;
  final List<Map<String, dynamic>> nextDepartures;

  const NextArrivalsDisplay({
    super.key,
    required this.stopName,
    required this.nextDepartures,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(stopName),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        children: [
          const ListTile(
            title: Row(
              children: [
                Expanded(
                  child: Center(
                    child: Text('Route Name', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Text('Next Arrival', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: nextDepartures.length,
              itemBuilder: (context, index) {
                final departure = nextDepartures[index];
                return ListTile(
                  title: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                        child: Row(
                        children: [
                          Expanded(
                          child: Center(
                            child: Text(departure["route_short_name"]),
                          ),
                          ),
                          Expanded(
                          child: Center(
                            child: Text('${rti.calculateMinutesToArrival(departure["arrival_time"])} min'),
                          ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}