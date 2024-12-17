import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

// prompt user for location permission
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

  // List of text for navigation
  static const List<Text> _navigationText = <Text>[
    Text('Real Time Information'),
    Text('Timetable'),
    Text('Routes'),
    Text('Fare Cost'),
  ];

  // List of pages to display based on navigation selection
  static final List<Widget> _pages = <Widget>[
    Column(children: [
      const Padding(
        padding: EdgeInsets.only(top: 32.0, left: 16.0, right: 16.0),
        child: SearchBar(
          hintText: 'Search for a bus stop...',
          trailing: [Icon(Icons.search)],
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: FutureBuilder<Position>(
          future: Geolocator.getCurrentPosition(locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.best,
            distanceFilter: 10,
          )),
          builder: (BuildContext context, AsyncSnapshot<Position> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text('Error: ${snapshot.error}');
        } else if (snapshot.hasData) {
          final position = snapshot.data!;
          return Text('Latitude: ${position.latitude}, Longitude: ${position.longitude}');
        } else {
          return const Text('No location data available');
        }
          },
        ),
      ),
    ],),
    Center(child: _navigationText[1]),
    Center(child: _navigationText[2]),
    Center(child: _navigationText[3]),
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
        actions: <Widget>[
          IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {},
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.timer_outlined),
            selectedIcon: Icon(Icons.timer),
            label: 'Real Time Info',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Timetable',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map),
            label: 'Routes',
          ),
          NavigationDestination(
            icon: Icon(Icons.euro_outlined),
            selectedIcon: Icon(Icons.euro),
            label: 'Fare Cost',
          ),
        ],
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: Theme.of(context).colorScheme.primary.withOpacity(0.2),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
    );
  }
}
