import 'package:better_tfi/widgets/search_result_route_display.dart';
import 'package:flutter/material.dart';

class SearchTimetableDisplay extends StatefulWidget {
  final String apiBaseUrl2;
  const SearchTimetableDisplay({super.key, required this.apiBaseUrl2});

  @override
  State<SearchTimetableDisplay> createState() => _SearchTimetableDisplayState();
}

class _SearchTimetableDisplayState extends State<SearchTimetableDisplay> {
  String searchQuery = '';

  @override
Widget build(BuildContext context) {
  return Column(
    children: [
      Padding(
        padding: const EdgeInsets.only(top: 32, left: 16, right: 16),
        child: SearchBar(
          hintText: "Search for a route...",
          trailing: [Icon(Icons.search)],
          onChanged: (value) {
            setState(() {
              searchQuery = value;
            });
          },
        ),
      ),
      const SizedBox(height: 16), // optional spacing
      Expanded(
        child: searchQuery.isEmpty
            ? Center(child: Text("Saved routes will appear here."))
            : SearchResultRouteDisplay(
                apiBaseUrl2: widget.apiBaseUrl2,
                searchQuery: searchQuery,
              ),
      ),
    ],
  );
}
}