import 'package:better_tfi/widgets/search_timetable_display.dart';
import 'package:flutter/material.dart';

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
  }
}
