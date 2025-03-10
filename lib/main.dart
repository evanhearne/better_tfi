import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'pages/real_time_info_page.dart';
import 'pages/timetable_page.dart';
import 'pages/routes_page.dart';
import 'pages/fare_cost_page.dart';

// Replace the strings here with your own API endpoints

const String apiBaseUrl1 = 'http://192.168.68.113:8080'; // gtfsr endpoint
const String apiBaseUrl2 = 'http://192.168.68.113:8081'; // csv endpoint

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Geolocator.requestPermission();
  runApp(MyApp(apiBaseUrl1: apiBaseUrl1, apiBaseUrl2: apiBaseUrl2));
}

class MyApp extends StatelessWidget {
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const MyApp({super.key, required this.apiBaseUrl1, required this.apiBaseUrl2});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BetterTFI',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(162, 0, 255, 191)),
        useMaterial3: true,
      ),
      home: MyHomePage(apiBaseUrl1: apiBaseUrl1, apiBaseUrl2: apiBaseUrl2),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final String apiBaseUrl1;
  final String apiBaseUrl2;

  const MyHomePage({super.key, required this.apiBaseUrl1, required this.apiBaseUrl2});

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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = <Widget>[
      RealTimeInfoPage(apiBaseUrl1: widget.apiBaseUrl1, apiBaseUrl2: widget.apiBaseUrl2),
      const TimetablePage(),
      const RoutesPage(),
      const FareCostPage(),
    ];
  }

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
