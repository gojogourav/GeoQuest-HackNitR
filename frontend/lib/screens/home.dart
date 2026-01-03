// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/discovery.dart';
import 'package:frontend/screens/authScreen.dart';
import 'package:frontend/screens/cameraScreen.dart';
import 'package:frontend/screens/imagePreviewScreen.dart';
import 'package:frontend/screens/storedImageScreen.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  CameraPosition? _initialCameraPosition;
  GoogleMapController? _mapController;
  LatLng? _currentLocation;
  List<Discovery> _discoveries = [];
  Set<Marker> _markers = {};

  @override
  void initState() {
    super.initState();
    _loadLocations();
    loadDiscoveries();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  // Go to current loacation of user
  Future<void> _goToCurrentLocation() async {
    // fall back
    if (_mapController == null) return;

    final location = _currentLocation ?? await getCurrentLocation();
    _currentLocation = location;
    _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 19),
      ),
    );
  }

  // Load the lacation of user
  Future<void> _loadLocations() async {
    try {
      final location = await getCurrentLocation();
      setState(() {
        _currentLocation = location;
        _initialCameraPosition = CameraPosition(target: location, zoom: 15);
      });
    } catch (e) {}
  }

  // load discoveries
  Future<void> loadDiscoveries() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('discoveries') ?? [];
    _discoveries = list.map((e) => Discovery.fromJson(json.decode(e))).toList();

    _markers = _discoveries.map((d) {
      return Marker(
        markerId: MarkerId(d.imagePath),
        position: LatLng(d.lat, d.lng),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ImagePreviewScreen(imagePath: d.imagePath),
            ),
          );
        },
      );
    }).toSet();
    setState(() {});
  }

  // Opening camera function
  Future<void> openCamera(BuildContext context) async {
    final imagePath = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const CameraScreen()),
    );

    if (imagePath == null || _currentLocation == null) return;

    final prefs = await SharedPreferences.getInstance();

    // Save Image path in local device storage
    final images = prefs.getStringList('images') ?? [];
    images.insert(0, imagePath);
    await prefs.setStringList('images', images);

    // Create Discovery
    final discovery = Discovery(
      imagePath: imagePath,
      lat: _currentLocation!.latitude,
      lng: _currentLocation!.longitude,
      plantData: {}, // later fill by AI
    );

    // save discovers in local
    final discoveries = prefs.getStringList('discoveries') ?? [];

    // Prevent duplicates
    final exists = discoveries.any((d) {
      final decoded = json.decode(d);
      return decoded['imagePath'] == imagePath;
    });

    if (!exists) {
      discoveries.add(json.encode(discovery.toJson()));
      await prefs.setStringList('discoveries', discoveries);
    }

    // update map marker
    // await loadDiscoveries();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ImagePreviewScreen(imagePath: imagePath),
      ),
    );
  }

  // }
  @override
  Widget build(BuildContext context) {
    if (_initialCameraPosition == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      body: Stack(
        children: [
          // MAP
          GoogleMap(
            initialCameraPosition: _initialCameraPosition!,
            markers: _markers,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            compassEnabled: false,
            mapToolbarEnabled: false,
            tiltGesturesEnabled: true,
            rotateGesturesEnabled: true,
            buildingsEnabled: true,
            indoorViewEnabled: true,
            mapType: MapType.normal,
            onMapCreated: (controller) {
              _mapController = controller;
            },
          ),

          /// TOP GLASS APP BAR
          Positioned(
            top: 50,
            left: 16,
            right: 16,
            child: _glassContainer(
              height: 72,
              child: Row(
                children: [
                  IconButton(
                    onPressed: _goToCurrentLocation,
                    icon: const Icon(Icons.my_location, color: Colors.white),
                  ),
                  const Expanded(
                    child: Center(
                      child: Text(
                        'GeoQuest',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const StoredImageScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.photo_library, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),

          /// CAMERA FLOATING BUTTON
          Positioned(
            bottom: 130,
            right: 10,
            child: GestureDetector(
              onTap: () => openCamera(context),
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Colors.greenAccent, Colors.tealAccent],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.6),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt,
                  color: Colors.black,
                  size: 32,
                ),
              ),
            ),
          ),

          /// LoaggOut FLOATING BUTTON
          Positioned(
            bottom: 130,
            left: 10,
            child: GestureDetector(
              onTap: () async {
                final auth = AuthService();
                await auth.signOut();
                if (mounted) {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                }
              },
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,

                  boxShadow: [
                    BoxShadow(
                      color: Colors.greenAccent.withOpacity(0.6),
                      blurRadius: 24,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: const Icon(Icons.logout, color: Colors.black, size: 32),
              ),
            ),
          ),

          /// BOTTOM GLASS NAV
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: _glassContainer(
              height: 68,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: const [
                  Icon(Icons.person_outline, color: Colors.white, size: 28),
                  Icon(Icons.home_filled, color: Colors.white, size: 30),
                  Icon(Icons.settings_outlined, color: Colors.white, size: 28),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// GLASS CONTAINER
  Widget _glassContainer({required double height, required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: const Color.fromARGB(255, 255, 255, 255).withOpacity(0.6),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              color: Colors.black.withOpacity(0.45),
              border: Border.all(
                color: Colors.white.withOpacity(0.08),
                width: 1,
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}

// LOCATION HELPER
Future<LatLng> getCurrentLocation() async {
  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    throw Exception('Location services disabled');
  }

  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied) {
    permission = await Geolocator.requestPermission();
  }

  if (permission == LocationPermission.deniedForever) {
    throw Exception('Location permission denied forever');
  }

  final position = await Geolocator.getCurrentPosition(
    desiredAccuracy: LocationAccuracy.high,
  );

  return LatLng(position.latitude, position.longitude);
}
