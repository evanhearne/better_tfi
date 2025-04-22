import 'package:flutter/material.dart';

class TimetableDisplay extends StatelessWidget {
  final Map<String, dynamic> timetable;
  const TimetableDisplay(
    {
      super.key,
      required this.timetable
      }
    );

  @override
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: Future.value(''),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Error: ${snapshot.error}'));
        } else {
          var timetables = timetable['timetables'];

            final PageController pageController = PageController();

            return Column(
            children: [
              Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                onPressed: () {
                  if (pageController.page! > 0) {
                  pageController.previousPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  }
                },
                child: Text('Previous'),
                ),
                ElevatedButton(
                onPressed: () {
                  if (pageController.page! < timetables.length - 1) {
                  pageController.nextPage(
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                  }
                },
                child: Text('Next'),
                ),
              ],
              ),
              Expanded(
              child: PageView.builder(
                controller: pageController,
                itemCount: timetables.length,
                itemBuilder: (context, index) {
                var dayTimetable = timetables[index];
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    '${dayTimetable['day'][0].toUpperCase()}${dayTimetable['day'].substring(1).toLowerCase()}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: DataTable(
                      columns: [
                        DataColumn(
                        label: Text(
                          'Stops',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        ),
                        for (var _ in dayTimetable['trips'])
                        DataColumn(label: Text('')),
                      ],
                      rows: [
                        for (var stop in dayTimetable['trips']
                          .expand((trip) => (trip['stop_names'] as List).cast<String>())
                          .toSet()
                          .toList())
                        DataRow(
                          cells: [
                          DataCell(Text(stop)),
                          ...dayTimetable['trips'].map((trip) {
                            final stopIndex = (trip['stop_names'] as List).indexOf(stop);
                            return DataCell(Text(stopIndex != -1
                              ? (trip['arrival_times'] as List)[stopIndex]
                              : ''));
                          }).toList(),
                          ],
                        ),
                      ],
                      ),
                    ),
                    ),
                  ),
                  ],
                );
                },
              ),
              ),
            ],
            );
        }
      },
    );
  }
}