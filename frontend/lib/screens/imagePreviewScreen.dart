
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/api.service.dart';
import 'package:geolocator/geolocator.dart';

class ImagePreviewScreen extends StatefulWidget {
  final String imagePath;

  const ImagePreviewScreen({super.key, required this.imagePath});

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  Map<String, dynamic>? plantData;
  bool isLoading = true;
  String loadingMessage = "Initializing Scan...";
  bool hasError = false;
  String errorMessage = "";

  String get _cacheKey => "plant_data_${widget.imagePath}";

  @override
  void initState() {
    super.initState();
    _loadFromCacheOrGenerate();
  }

  // cache handle
  Future<void> _loadFromCacheOrGenerate() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(_cacheKey);

    if (cached != null) {
      setState(() {
        plantData = json.decode(cached);
        isLoading = false;
      });
    } else {
      await _generateAndSave();
    }
  }

  // generate data
  Future<bool> _generateAndSave() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception("User not logged in");
      }
      final token = await user.getIdToken();
      if (token == null) {
        throw Exception("Failed to retrieve auth token");
      }

      // --- Location & Geocoding ---
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
           throw Exception("Location permissions are denied");
        }
      }
      
      if (permission == LocationPermission.deniedForever) {
        throw Exception("Location permissions are permanently denied");
      }

      final Position position = await Geolocator.getCurrentPosition();
      



      String? district;
      String? state;
      String? country;

      try {
        setState(() {
          loadingMessage = "Detecting Location...";
        });

        final place = await _getPlaceFromCoordinates(position.latitude, position.longitude);
        district = place["district"];
        state = place["state"];
        country = place["country"];

        if (state != null) {
           print("📍 Geocoding Success: District: $district, State: $state, Country: $country");
           setState(() {
            loadingMessage = "Scanning from ${district ?? ""}, $state...";
          });
        }
      } catch (e) {
        print("Geocoding logic error: $e");
      }

      final response = await ApiService.scanPlant(
        widget.imagePath, 
        token,
        latitude: position.latitude,
        longitude: position.longitude,
        district: district,
        state: state,
        country: country
      );

      if (response.statusCode == 400) {
         try {
           final errJson = json.decode(response.body);
           if (errJson['error'] == "Not a plant") {
             throw Exception("NOT_A_PLANT");
           }
           throw Exception(errJson['error'] ?? "Unknown Error");
         } catch (e) {
           if (e.toString().contains("NOT_A_PLANT")) rethrow;
           throw Exception("Analysis Failed: ${response.statusCode}");
         }
      }

      if (response.statusCode != 200) {
        throw Exception(response.body);
      }

      final jsonResponse = json.decode(response.body);
      final data = jsonResponse['plant_data'];

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, json.encode(data));

      setState(() {
        plantData = data;
        isLoading = false;
        hasError = false;
      });

      return true;
    } catch (e) {
      errorMessage = e.toString().replaceAll("Exception: ", "");
      hasError = true;
      isLoading = false;
      setState(() {});
      return false;
    }
  }

  // retry analysis
  Future<void> retryAnalysis() async {
    setState(() {
      isLoading = true;
      hasError = false;
      errorMessage = "";
    });
    await _generateAndSave();
  }

  // delete plant picture
  Future<void> deleteImageAndData() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_cacheKey); // remove the key

    final images = prefs.getStringList('images') ?? [];
    images.remove(widget.imagePath);
    await prefs.setStringList('images', images);

    final discoveries = prefs.getStringList('discoveries') ?? [];
    discoveries.removeWhere((d) {
      final jsonData = json.decode(d);
      return jsonData['imagePath'] == widget.imagePath;
    });
    await prefs.setStringList('discoveries', discoveries);

    final file = File(widget.imagePath);
    if (await file.exists()) {
      await file.delete();
    }

    if (mounted) {
      Navigator.pop(context, true);
    }
  }

  // card widget
  Widget _card(String title, IconData icon, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A).withOpacity(0.85),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Colors.greenAccent),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _confidenceBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "$label ${(value * 100).toStringAsFixed(0)}%",
          style: const TextStyle(color: Colors.white70),
        ),
        const SizedBox(height: 8),
        LinearProgressIndicator(
          value: value,
          minHeight: 12,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }

  Widget _authenticityBar(
    String title,
    String subtitle,
    double value,
    Color color,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(color: Colors.white)),
        Text(
          subtitle,
          style: const TextStyle(color: Colors.white70, fontSize: 13),
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(
          value: value,
          minHeight: 12,
          backgroundColor: Colors.white24,
          valueColor: AlwaysStoppedAnimation(color),
        ),
      ],
    );
  }

  // -------------------- BUILD --------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.file(File(widget.imagePath), fit: BoxFit.cover),
          ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.6),
                    Colors.black.withOpacity(0.85),
                  ],
                ),
              ),
            ),
          ),

          /// DELETE BUTTON (ALWAYS VISIBLE)
          Positioned(
            top: 34,
            right: 24,
            child: OutlinedButton.icon(
              onPressed: deleteImageAndData,
              icon: const Icon(Icons.delete),
              label: const Text("Delete"),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
              ),
            ),
          ),

          SafeArea(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.green),
                        const SizedBox(height: 16),
                        Text(
                           loadingMessage,
                           style: const TextStyle(color: Colors.white70, fontSize: 16),
                           textAlign: TextAlign.center,
                        )
                      ],
                    ),
                  )
                : hasError || plantData == null
                ? _errorView()
                : _contentSheet(),
          ),
        ],
      ),
    );
  }

  // -------------------- CONTENT --------------------
  // ... (content sheet remains same)

  // ... (helper methods remain same)

  Widget _errorView() {
    bool isNotPlant = errorMessage.contains("NOT_A_PLANT");

    if (isNotPlant) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
               Container(
                 padding: const EdgeInsets.all(24),
                 decoration: BoxDecoration(
                   color: Colors.redAccent.withOpacity(0.1),
                   shape: BoxShape.circle,
                   border: Border.all(color: Colors.redAccent.withOpacity(0.5), width: 2)
                 ),
                 child: const Icon(Icons.nature_outlined, color: Colors.redAccent, size: 64),
               ),
               const SizedBox(height: 24),
               const Text(
                 "Not a Plant?",
                 style: TextStyle(
                   color: Colors.white,
                   fontSize: 24,
                   fontWeight: FontWeight.bold,
                   letterSpacing: 1.1
                 ),
               ),
               const SizedBox(height: 12),
               const Text(
                 "Our scanners couldn't find a plant in this image. \nTry getting closer or using better lighting.",
                 textAlign: TextAlign.center,
                 style: TextStyle(color: Colors.white70, fontSize: 16, height: 1.5),
               ),
               const SizedBox(height: 32),
               SizedBox(
                 width: double.infinity,
                 child: ElevatedButton.icon(
                   style: ElevatedButton.styleFrom(
                     backgroundColor: Colors.white,
                     foregroundColor: Colors.black,
                     padding: const EdgeInsets.symmetric(vertical: 16),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   ),
                   onPressed: retryAnalysis,
                   icon: const Icon(Icons.refresh),
                   label: const Text("Try Again", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                 ),
               )
            ],
          ),
        ),
      );
    }

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.orangeAccent, size: 48),
            const SizedBox(height: 16),
            const Text(
              "Analysis Failed",
              style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              errorMessage.isNotEmpty ? errorMessage : "Unknown error occurred",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: retryAnalysis,
              child: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }


  // -------------------- CONTENT --------------------
  Widget _contentSheet() {
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, controller) {
        return ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              color: const Color(0xFF1E1E1E).withOpacity(0.85),
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.fromLTRB(22, 22, 22, 90),
                children: [
                   Center(
                    child: Container(
                      width: 46,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.white54,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title Section
                  Text(
                    plantData!["commonName"] ?? "Unknown Plant",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    plantData!["scientificName"] ?? "",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 20),

                  _card(
                    "Identification Confidence",
                    Icons.verified,
                    _confidenceBar(
                      "Accuracy",
                      (plantData!["confidence"] ?? 0.0).toDouble(),
                      Colors.greenAccent,
                    ),
                  ),

                  if (plantData!["health"] != null)
                  _card(
                    "Health Status",
                    Icons.healing,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                             Text(
                              plantData!["health"]["status"] ?? "UNKNOWN",
                              style: TextStyle(
                                color: _getHealthColor(plantData!["health"]["status"]),
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                             ),
                             const Spacer(),
                             Text(
                               "${plantData!["health"]["score"] ?? 0}%",
                               style: const TextStyle(color: Colors.white70),
                             ),
                          ],
                        ),
                        const SizedBox(height: 8),
                         LinearProgressIndicator(
                          value: (plantData!["health"]["score"] ?? 0) / 100.0,
                          minHeight: 8,
                          backgroundColor: Colors.white24,
                          valueColor: AlwaysStoppedAnimation(_getHealthColor(plantData!["health"]["status"])),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          plantData!["health"]["diagnosis"] ?? "",
                          style: const TextStyle(color: Colors.white70),
                        ),
                      ],
                    ),
                  ),

                   _card(
                    "Description",
                    Icons.info_outline,
                    Text(
                      plantData!["description"] ?? "",
                      style: const TextStyle(
                        color: Colors.white70,
                        height: 1.6,
                      ),
                    ),
                  ),

                  _card(
                    "Rarity",
                    Icons.public,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _buildInfoRow(Icons.stars, "Level", plantData!["rarity"]["level"] ?? "Unknown"),
                         _buildInfoRow(Icons.place, "Locality", plantData!["rarity"]["locality"] ?? "Unknown"),
                      ],
                    )
                  ),

                  if (plantData!["careSchedule"] != null)
                  _card(
                    "Care Schedule",
                    Icons.calendar_month,
                    Column(
                      children: (plantData!["careSchedule"] as List).map((task) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 12.0),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(_getActionIcon(task["action"]), color: Colors.greenAccent, size: 20),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      task["taskName"] ?? "",
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      "${task["difficulty"]} • ${task["timeOfDay"]}",
                                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                                    ),
                                     const SizedBox(height: 4),
                                    Text(
                                      task["instruction"] ?? "",
                                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                               Text(
                                "+${task["xpReward"]} XP",
                                style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  ElevatedButton.icon(
                    onPressed: retryAnalysis,
                    icon: const Icon(Icons.refresh),
                    label: const Text("Regenerate Details"),
                  ),

                  const SizedBox(height: 12),

                  OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: const Text("Delete this image?"),
                          content: const Text(
                            "This will permanently delete the image and its generated details.",
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text("Cancel"),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: const Text("Delete"),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await deleteImageAndData();
                      }
                    },
                    icon: const Icon(Icons.delete),
                    label: const Text("Delete Image"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- BigDataCloud Geocoding API ---
  Future<Map<String, String?>> _getPlaceFromCoordinates(double lat, double lng) async {
    // TODO: Replace with valid BigDataCloud API Key
    const apiKey = "bdc_af85516067754b20a400b86a111a14c2"; 
    final url = Uri.parse(
        "https://api-bdc.net/data/reverse-geocode?latitude=$lat&longitude=$lng&localityLanguage=en&key=$apiKey");

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Mapping fields based on BigDataCloud response schema
        String? district = data['city'];
        if (district == null || district.isEmpty) {
          district = data['locality'];
        }
        
        String? state = data['principalSubdivision'];
        String? country = data['countryName'];

        return {"district": district, "state": state, "country": country};
      } else {
        print("BigDataCloud API Error: ${response.statusCode} - ${response.body}");
      }
    } catch (e) {
      print("BigDataCloud Geocoding Error: $e");
    }
    return {"district": null, "state": null, "country": null};
  }

  // --- Helpers ---

  Color _getHealthColor(String? status) {
    switch (status) {
      case "HEALTHY": return Colors.green;
      case "WILTED": return Colors.orange;
      case "DISEASED": return Colors.red;
      default: return Colors.grey;
    }
  }

  IconData _getActionIcon(String? action) {
    switch (action) {
      case "WATER": return Icons.water_drop;
      case "FERTILIZE": return Icons.science;
      case "PRUNE": return Icons.content_cut;
      case "SUNLIGHT": return Icons.wb_sunny;
      default: return Icons.check_circle_outline;
    }
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Icon(icon, color: Colors.white54, size: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  value, 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
              )
          ),
        ],
      ),
    );
  }


}

