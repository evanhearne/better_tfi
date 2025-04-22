import 'package:better_tfi/widgets/timetable_display.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchResultRouteDisplay extends StatefulWidget {
  final String apiBaseUrl2;
  final String searchQuery;

  const SearchResultRouteDisplay({super.key, required this.apiBaseUrl2, required this.searchQuery});

  @override
  SearchResultRouteDisplayState createState() =>
      SearchResultRouteDisplayState();
}

class SearchResultRouteDisplayState extends State<SearchResultRouteDisplay> {
  late Future<List<RouteInfo>> _routes;

  @override
  void initState() {
    super.initState();
    _routes = fetchRoutes(widget.apiBaseUrl2, widget.searchQuery);
  }

  @override
  void didUpdateWidget(covariant SearchResultRouteDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.searchQuery != oldWidget.searchQuery) {
      setState(() {
        _routes = fetchRoutes(widget.apiBaseUrl2, widget.searchQuery);
      });
    }
  }

  Future<List<RouteInfo>> fetchRoutes(String apiBaseUrl2,String query) async {
    final response = await http.get(Uri.parse('$apiBaseUrl2/routes?search_query=$query'));

    if (response.statusCode == 200) {
      final Map<String,dynamic> data = json.decode(response.body);
      if ((data['routes'] == null)) {
        return [];
      }
      return (data['routes'] as List).map((route) {
        return RouteInfo(
          routeID: route['route_id'],
          routeShortName: route['route_short_name'],
          routeLongName: route['route_long_name'],
        );
      }).toList();
    } else {
      throw Exception('Failed to load routes');
    }
  }

  Future<Map<String, dynamic>> fetchTimetable(String apiBaseUrl2, String routeID) async {
    final response = await http.get(Uri.parse('$apiBaseUrl2/timetable?route_id=$routeID'));
    if (response.statusCode == 200) {
      final Map<String, dynamic> timetable = Map<String, dynamic>.from(jsonDecode(response.body));
      return timetable;
    } else {
      throw Exception('Failed to load timetable');
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<RouteInfo>>(
        future: _routes,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No routes found'));
          } else {
            final routes = snapshot.data!;
            return ListView.builder(
              itemCount: routes.length,
              itemBuilder: (context, index) {
                final route = routes[index];
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                  child: ListTile(
                    title: Text(route.routeShortName),
                    subtitle: Text(route.routeLongName),
                    onTap: () =>  Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => Scaffold(
                    appBar: AppBar(
                      title: Text('${route.routeShortName} Timetable'),
                    ),
                    body: FutureBuilder<Map<String, dynamic>>(
                      future: fetchTimetable(widget.apiBaseUrl2, route.routeID),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator());
                        } else if (snapshot.hasError) {
                          return Center(child: Text('Error: ${snapshot.error}'));
                        } else if (!snapshot.hasData) {
                          return Center(child: Text('No timetable available'));
                        } else {
                          return TimetableDisplay(timetable: snapshot.data!);
                        }
                      },
                    ),
                  ),
                ),
              ),
                  ),
                );
              },
            );
          }
        },
    );
  }
}

class RouteInfo {
  final String routeID;
  final String routeShortName;
  final String routeLongName;

  RouteInfo({required this.routeID, required this.routeShortName, required this.routeLongName});
}