import 'package:flutter/material.dart';

class TimetablePage extends StatelessWidget {
  const TimetablePage({super.key});

  @override
  Widget build(BuildContext context) {
    var stops = List<Widget>.generate(
      20,
      (index) => Text("Stop ${index + 1}"),
    );
    var times = List<String>.generate(
      37,
      (index) {
      final hour = 7 + (index * 20 ~/ 60);
      final minute = (index * 20) % 60;
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
      },
    );
    return Column(
      children: [
      Expanded(
        child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SingleChildScrollView(
          scrollDirection: Axis.vertical,
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DataTable(
        columns: [
          DataColumn(label: Text(
                'Day of Week',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              )),
          for (var time in times) DataColumn(label: Text('')),
        ],
        rows: [
          for (var stop in stops)
            DataRow(
          cells: [
            DataCell(stop),
            ...List.generate(37, (index) => DataCell(Text(times[index]))),
          ],
            ),
        ],
          )]),
        ),
      ),
    ),
      ],
    );
  }
}


// Use Route Endpoint

// Have a way to view all routes or search for one.

// If View All Routes have columns 
// route no   name

// on scroll paginate every 8

// Otherwise on search have columns
// route no   name

// on scroll paginate every 8

// On card click...
// show timetable which has view like

// route name
// day (Mon-Sun)
// time across day
// stops at first column of row but multiple rows
