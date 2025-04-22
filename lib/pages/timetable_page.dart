import 'dart:convert';

import 'package:better_tfi/widgets/search_timetable_display.dart';
import 'package:better_tfi/widgets/timetable_display.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class TimetablePage extends StatelessWidget {
  final String apiBaseUrl2;
  const TimetablePage(
    {
      super.key,
      required this.apiBaseUrl2
  });
  @override
  Widget build(BuildContext context) {
    return SearchTimetableDisplay(apiBaseUrl2: apiBaseUrl2,);
    // return FutureBuilder<Widget>(
    //   future: _fetchTimetable(),
    //   builder: (context, snapshot) {
    //     if (snapshot.connectionState == ConnectionState.waiting) {
    //       return Center(child: CircularProgressIndicator());
    //     } else if (snapshot.hasError) {
    //       return Center(child: Text('Error: ${snapshot.error}'));
    //     } else {
    //       return snapshot.data ?? Center(child: Text('No data available'));
    //     }
    //   },
    // );
  }
}
