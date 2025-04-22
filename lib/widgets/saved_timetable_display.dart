import 'package:flutter/material.dart';

class SavedTimetableDisplay extends StatelessWidget {
  const SavedTimetableDisplay({super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
        padding: EdgeInsets.all(16),
        child: ListTile(
        title: Column(
          children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Center(child: Text("Saved Routes", style: TextStyle(fontSize: 24),)),
            ],
          ),
          Padding(padding: EdgeInsets.only(top: 16), child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
            Expanded(
              child: Center(
              child: Text(
                'Route Number',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ),
            ),
            Expanded(
              child: Center(
              child: Text(
                'Name',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ),
            ),
            ],
          ),),
          ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Adjust padding if needed
        title: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
          Expanded(
            child: Center(
              child: Text("W2"),
            ),
          ),
          Expanded(
            child: Center(
              child: Text("The Quay - WIT"),
            ),
          ),
              ],
            ),
          ),
        )
      )
          ],
        ),
        ),
      );
  }
  
}