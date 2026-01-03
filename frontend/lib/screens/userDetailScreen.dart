import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/models/discovery.dart';
import 'package:frontend/services/api.service.dart';
import 'package:frontend/screens/imagePreviewScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserDetailScreen extends StatefulWidget {
  const UserDetailScreen({super.key});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  String userName = "Explorer";
  String? userPhoto;
  int userLevel = 1;
  int userXp = 0;
  List<Discovery> discoveries = [];
  List<dynamic> xpHistory = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final token = await user.getIdToken();
      if (token == null) return;

      final profileFuture = ApiService.syncUserWithBackend(token);
      final discoveriesFuture = ApiService.getUserDiscoveries(token);
      final historyFuture = ApiService.getXPHistory(token);

      final results = await Future.wait([
        profileFuture,
        discoveriesFuture,
        historyFuture,
      ]);
      final profileData = results[0] as Map<String, dynamic>?;
      final discoveriesList = results[1] as List<dynamic>;
      final historyList = results[2] as List<dynamic>;

      final mappedDiscoveries = discoveriesList.map((d) {
        return Discovery(
          imagePath: d['imageUrl'] ?? "",
          lat: (d['latitude'] as num?)?.toDouble() ?? 0.0,
          lng: (d['longitude'] as num?)?.toDouble() ?? 0.0,
          plantData: {
            "commonName": d['object']?['commonName'] ?? "Unidentified",
            "canonicalName": d['object']?['canonicalName'],
            "scientificName": d['object']?['scientificName'],
            "description": d['object']?['description'],
            "health": {
              "score": d['healthScore'] ?? 0,
              "status": "Check Details",
            },
            "confidence": d['confidence'] ?? 1.0,
            // Rarity is complex to reconstruct from this endpoint, leaving null is safe now
          },
        );
      }).toList();

      if (mounted) {
        setState(() {
          if (profileData != null) {
            userName =
                profileData['username'] ?? user.displayName ?? "Explorer";
            userXp = profileData['xp'] ?? 0;
            userLevel = profileData['level'] ?? 1;
            userPhoto = user.photoURL;
          }
          discoveries = mappedDiscoveries;
          xpHistory = historyList;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: Stack(
        children: [
          // Background Gradient (Fixed behind scroll)
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0F2027),
                    Color(0xFF203A43),
                    Color(0xFF2C5364),
                  ],
                ),
              ),
            ),
          ),

          isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.greenAccent),
                )
              : CustomScrollView(
                  slivers: [
                    // 1. Profile + Stats Header
                    SliverToBoxAdapter(
                      child: SafeArea(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 40, 20, 20),
                          child: Column(
                            children: [
                              const SizedBox(height: 20),
                              _buildProfileHeader(),
                              const SizedBox(height: 30),
                              _buildStatsRow(),
                              const SizedBox(height: 30),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Your Garden",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    // 2. Plant Grid (StoredImageScreen Style)
                    discoveries.isEmpty
                        ? SliverFillRemaining(
                            hasScrollBody: false,
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 100),
                                child: Text(
                                  "No plants found yet.\nStart scanning!",
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                  ),
                                ),
                              ),
                            ),
                          )
                        : SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                            sliver: SliverGrid(
                              delegate: SliverChildBuilderDelegate((
                                context,
                                index,
                              ) {
                                final discovery = discoveries[index];
                                return _buildPlantCard(discovery);
                              }, childCount: discoveries.length),
                              gridDelegate:
                                  const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 16,
                                    childAspectRatio: 0.9,
                                  ),
                            ),
                          ),
                  ],
                ),

          // Custom Back Button (Overlay)
          Positioned(
            top: 40,
            left: 20,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white24),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new,
                  color: Colors.white,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.greenAccent, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.greenAccent.withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[800],
            backgroundImage: userPhoto != null
                ? NetworkImage(userPhoto!)
                : null,
            child: userPhoto == null
                ? const Icon(Icons.person, size: 50, color: Colors.white)
                : null,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          userName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.greenAccent.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.5)),
          ),
          child: Text(
            "Level $userLevel Botanist",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsRow() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem("Total XP", "$userXp", Icons.bolt, Colors.orange),
          Container(width: 1, height: 40, color: Colors.white24),
          _buildStatItem(
            "Plants",
            "${discoveries.length}",
            Icons.local_florist,
            Colors.green,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }

  // Uses StoredImageScreen card styling but with backend data
  Widget _buildPlantCard(Discovery discovery) {
    final data = discovery.plantData;
    String displayName = "Unidentified Plant";
    if (data['canonicalName']?.toString().isNotEmpty == true) {
      displayName = data['canonicalName'];
    } else if (data['commonName']?.toString().isNotEmpty == true) {
      displayName = data['commonName'];
    }

    // Isolate Health logic if needed, but StoredImageScreen is just an image.
    // We will keep the image focus but add a small overlay for context.

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ImagePreviewScreen(
              imagePath: discovery.imagePath,
              existingData: discovery.plantData, // Pass data for view-only
            ),
          ),
        );
      },
      child: Hero(
        tag: 'image_${discovery.imagePath}',
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(
                  0.2,
                ), // Darker shadow for dark bg
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              fit: StackFit.expand,
              children: [
                (discovery.imagePath.startsWith("http"))
                    ? Image.network(discovery.imagePath, fit: BoxFit.cover)
                    : Image.file(File(discovery.imagePath), fit: BoxFit.cover),

                // Subtle Gradient Overlay for Text Visibility
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withOpacity(0.8),
                        ],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 10,
                  left: 12,
                  right: 12,
                  child: Text(
                    displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none, // Fix Hero text glitch
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
