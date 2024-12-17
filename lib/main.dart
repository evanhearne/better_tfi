import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'pages/real_time_info_page.dart';
import 'pages/timetable_page.dart';
import 'pages/routes_page.dart';
import 'pages/fare_cost_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.requestPermission();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BetterTFI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(162, 0, 255, 191)),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _selectedIndex = 0;

  static const List<Text> _navigationText = <Text>[
    Text('Real Time Information'),
    Text('Timetable'),
    Text('Routes'),
    Text('Fare Cost'),
  ];

  static final List<Widget> _pages = <Widget>[
    const RealTimeInfoPage(),
    const TimetablePage(),
    const RoutesPage(),
    const FareCostPage(),
  ];

  void _onDestinationSelected(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Align(
          alignment: Alignment.centerLeft,
          child: _navigationText[_selectedIndex],
        ),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const <NavigationDestination>[
          NavigationDestination(icon: Icon(Icons.timer_outlined), label: 'Real Time Info'),
          NavigationDestination(icon: Icon(Icons.list_alt_outlined), label: 'Timetable'),
          NavigationDestination(icon: Icon(Icons.map_outlined), label: 'Routes'),
          NavigationDestination(icon: Icon(Icons.euro_outlined), label: 'Fare Cost'),
        ],
      ),
    );
  }
}
