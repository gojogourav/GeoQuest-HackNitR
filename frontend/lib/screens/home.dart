// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:frontend/models/discovery.dart';
import 'package:frontend/screens/cameraScreen.dart';
import 'package:frontend/screens/imagePreviewScreen.dart';
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
            MaterialPageRoute(builder: (_) => ImagePreviewScreen()),
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
      MaterialPageRoute(builder: (_) => ImagePreviewScreen()),
    );
  }

  // }
  @override
  Widget build(BuildContext context) {
    return Scaffold();
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
