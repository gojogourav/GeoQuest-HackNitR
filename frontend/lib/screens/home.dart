// ignore_for_file: unused_element, unused_field, unused_local_variable

import 'dart:convert' hide Codec;
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:frontend/services/auth_service.dart';
import 'package:frontend/models/discovery.dart';
import 'package:frontend/screens/authScreen.dart';
import 'package:frontend/screens/cameraScreen.dart';
import 'package:frontend/screens/imagePreviewScreen.dart';
import 'package:frontend/screens/storedImageScreen.dart';
import 'package:frontend/screens/leader.dart';
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
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _showLocationchip = false;
  Timer? _locationtimer;

  @override
  void initState() {
    super.initState();
    _loadLocations();
    _startLocationUpdates();
    loadDiscoveries();
  }

  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }

  void _startLocationUpdates() {
    _positionStreamSubscription =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (!mounted) return;
          setState(() {
            _currentLocation = LatLng(position.latitude, position.longitude);
          });
        });
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
    _locationtimer?.cancel();

    setState(() {
      _showLocationchip = true;
      _locationtimer = Timer(const Duration(seconds: 5), () {
        if (mounted) {
          setState(() {
            _showLocationchip = false;
          });
        }
      });
    });
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

  // Create custom marker with image
  Future<BitmapDescriptor> _createCustomMarkerBitmap(String imagePath) async {
    try {
      final File imageFile = File(imagePath);
      if (!await imageFile.exists()) {
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
      }

      final Uint8List imageBytes = await imageFile.readAsBytes();
      final ui.Codec codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: 150,
        targetHeight: 150,
      );
      final ui.FrameInfo frameInfo = await codec.getNextFrame();
      final ui.Image image = frameInfo.image;

      final ui.PictureRecorder pictureRecorder = ui.PictureRecorder();
      final Canvas canvas = Canvas(pictureRecorder);
      final double size = 150.0;
      final double radius = size / 2;

      // Draw circle background/border
      final Paint paint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;

      canvas.drawCircle(Offset(radius, radius), radius, paint);

      // Draw Image in circle
      final Path clipPath = Path()
        ..addOval(
          Rect.fromCircle(center: Offset(radius, radius), radius: radius - 8),
        ); // 8 is border width

      canvas.clipPath(clipPath);

      // Scale image to fit
      final double imageSize =
          size; // Assuming square for simplicity or handled by codec
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, imageSize, imageSize),
        Paint(),
      );

      final ui.Picture picture = pictureRecorder.endRecording();
      final ui.Image img = await picture.toImage(size.toInt(), size.toInt());
      final ByteData? byteData = await img.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData == null)
        return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);

      return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
    } catch (e) {
      print("Error creating marker: $e");
      return BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    }
  }

  // load discoveries
  Future<void> loadDiscoveries() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('discoveries') ?? [];
    _discoveries = list.map((e) => Discovery.fromJson(json.decode(e))).toList();

    _markers = {};

    for (var d in _discoveries) {
      final icon = await _createCustomMarkerBitmap(d.imagePath);
      _markers.add(
        Marker(
          markerId: MarkerId(d.imagePath),
          position: LatLng(d.lat, d.lng),
          icon: icon,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ImagePreviewScreen(imagePath: d.imagePath),
              ),
            );
          },
        ),
      );
    }

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

  //
  final String cleanMapStyle = '''
[
  {
    "featureType": "poi",
    "stylers": [{ "visibility": "off" }]
  },
  {
    "featureType": "transit",
    "stylers": [{ "visibility": "on" }]
  },
  {
    "featureType": "administrative",
    "elementType": "labels",
    "stylers": [{ "visibility": "on" }]
  },
  {
    "featureType": "road",
    "elementType": "labels",
    "stylers": [{ "visibility": "on" }]
  }
]
''';

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
            markers: _markers, // only own markers
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
              _mapController!.setMapStyle(cleanMapStyle);
            },
          ),

          // current location
          if (_showLocationchip)
            Positioned(
              top: 150,
              left: 16,
              child: AnimatedOpacity(
                opacity: _showLocationchip ? 1 : 0,
                duration: const Duration(milliseconds: 800),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 1000),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: (_currentLocation != null)
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.my_location,
                              size: 16,
                              color: Colors.greenAccent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${_currentLocation!.latitude.toStringAsFixed(4)}, '
                              '${_currentLocation!.longitude.toStringAsFixed(4)}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.4,
                              ),
                            ),
                          ],
                        )
                      : const Text(
                          "Location unavailable",
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                ),
              ),
            ),

          /// TOP GLASS APP BAR
          // Positioned(
          //   top: 64,
          //   left: 0,
          //   right: 0,
          //   child: Align(
          //     alignment: Alignment.topCenter,
          // child: ClipRRect(
          //   borderRadius: BorderRadius.circular(34),
          //   child: BackdropFilter(
          //     filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          //     child: Container(
          //       padding: const EdgeInsets.symmetric(
          //         horizontal: 22,
          //         vertical: 12,
          //       ),
          //       decoration: BoxDecoration(
          //         color: Colors.black.withOpacity(0.35), // 👈 key change
          //         borderRadius: BorderRadius.circular(34),
          //         border: Border.all(
          //           color: Colors.white.withOpacity(0.18),
          //           width: 1,
          //         ),
          //         boxShadow: [
          //           BoxShadow(
          //             color: Colors.black.withOpacity(0.25),
          //             blurRadius: 18,
          //             offset: const Offset(0, 10),
          //           ),
          //         ],
          //       ),
          //           child: const Text(
          //             "GeoQuest",
          //             style: TextStyle(
          //               color: Colors.white,
          //               fontWeight: FontWeight.w700,
          //               fontSize: 20,
          //               letterSpacing: 1.3,
          //             ),
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),

          // location botton
          // Positioned(
          //   top: 64, // aligns vertically with title
          //   right: 20,
          //   child: GestureDetector(
          //     onTap: _goToCurrentLocation, // optional
          //     child: ClipOval(
          //       child: BackdropFilter(
          //         filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          //         child: Container(
          //           width: 42,
          //           height: 42,
          //           decoration: BoxDecoration(
          //             color: Colors.black.withOpacity(0.4),
          //             border: Border.all(
          //               color: Colors.greenAccent.withOpacity(0.4),
          //             ),
          //             shape: BoxShape.circle,
          //             boxShadow: [
          //               BoxShadow(
          //                 color: Colors.greenAccent.withOpacity(0.3),
          //                 blurRadius: 12,
          //               ),
          //             ],
          //           ),
          //           child: const Icon(
          //             Icons.my_location,
          //             color: Colors.greenAccent,
          //             size: 22,
          //           ),
          //         ),
          //       ),
          //     ),
          //   ),
          // ),
          Positioned(
            top: 55,
            left: 0,
            right: 0,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  right: 30,
                  child: InkWell(
                    onTap: _goToCurrentLocation,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 22,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(34),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.18),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.25),
                            blurRadius: 18,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: const Icon(
                          Icons.rocket_launch,
                          color: Colors.greenAccent,
                          size: 22,
                        ),
                      ),
                    ),
                  ),
                ),

                Align(
                  alignment: Alignment.topCenter,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(34),
                    child: BackdropFilter(
                      filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(
                            0.35,
                          ), // 👈 key change
                          borderRadius: BorderRadius.circular(34),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.18),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.25),
                              blurRadius: 18,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Text(
                          "GeoQuest",
                          style: const TextStyle(
                            // fontFamily: 'AppleEmoji',
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 20,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          /// BOTTOM GLASS NAV
          Positioned(
            bottom: 24,
            left: 16,
            right: 16,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
                child: Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.16), // softer glass
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(
                      color: const Color.fromARGB(
                        255,
                        20,
                        224,
                        6,
                      ).withOpacity(0.22),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.18),
                        blurRadius: 30,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: _actionTile(
                              icon: Icons.camera_alt,
                              label: "Camera",
                              color: Colors.green,
                              onTap: () => openCamera(context),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _actionTile(
                              icon: Icons.photo_library,
                              label: "Photos",
                              color: Colors.blue,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const StoredImageScreen(),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _actionTile(
                              icon: Icons.leaderboard,
                              label: "Leaderboard",
                              color: Colors.orange,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) =>
                                        const LeaderboardPage(),
                                  ),
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _actionTile(
                              icon: Icons.logout,
                              label: "LogOut",
                              color: Colors.purple,
                              onTap: () async {
                                final auth = AuthService();
                                await auth.signOut();
                                if (mounted) {
                                  Navigator.pushReplacement(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => const LoginPage(),
                                    ),
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Positioned(
          //   bottom: 24,
          //   left: 16,
          //   right: 16,
          //   child: _glassContainer(
          //     height: 68,
          //     child: Row(
          //       mainAxisAlignment: MainAxisAlignment.spaceAround,
          //       children: const [
          //         Icon(Icons.person_outline, color: Colors.white, size: 28),
          //         Icon(Icons.home_filled, color: Colors.white, size: 30),
          //         Icon(Icons.settings_outlined, color: Colors.white, size: 28),
          //       ],
          //     ),
          //   ),
          // ),
        ],
      ),
    );
  }

  Widget _actionTile({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 90,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.25), color.withOpacity(0.12)],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.25)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 30),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
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
          filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
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
