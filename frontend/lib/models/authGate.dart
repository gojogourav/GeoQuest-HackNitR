import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/screens/authScreen.dart';
import 'package:frontend/screens/home.dart';
import 'package:geolocator/geolocator.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  bool _isLocationPermissionGranted = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkPermissionAndInit();
  }

  Future<void> _checkPermissionAndInit() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't disable the UI
      // because we want to ask for permission first?
      // Actually usually we need service enabled too.
      // For now let's focus on permission as requested.
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        setState(() {
          _isLocationPermissionGranted = false;
          _isLoading = false;
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      setState(() {
        _isLocationPermissionGranted = false;
        _isLoading = false;
      });
      return;
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    setState(() {
      _isLocationPermissionGranted = true;
    });

    _initApp();
  }

  Future<void> _initApp() async {
    // Wait a bit to show splash/loading if desired, or skip
    await Future.delayed(const Duration(seconds: 2));

    var user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      _openLogin();
    } else {
      _openMainScreen();
    }
  }

  void _openLogin() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => LoginPage()),
    );
  }

  void _openMainScreen() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color.fromARGB(255, 3, 21, 8),
                  Color.fromARGB(255, 1, 6, 3),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (!_isLocationPermissionGranted && !_isLoading) ...[
                    const Icon(
                      Icons.location_off,
                      size: 60,
                      color: Colors.redAccent,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Location Permission Required",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "To use GeoQuest, please grant location access.",
                      style: TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: _checkPermissionAndInit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 30,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "Grant Permission",
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextButton(
                      onPressed: () => Geolocator.openAppSettings(),
                      child: const Text(
                        "Open Settings",
                        style: TextStyle(color: Colors.blueAccent),
                      ),
                    ),
                  ] else ...[
                    const Text(
                      "GeoQuest",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 32,
                        letterSpacing: 2,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "Explore the world",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        letterSpacing: 3,
                        color: Colors.white70,
                      ),
                    ),
                    const SizedBox(height: 40),
                    LinearProgressIndicator(
                      backgroundColor: const Color.fromARGB(255, 37, 37, 37),
                      color: const Color.fromARGB(255, 6, 175, 37),
                      minHeight: 6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
