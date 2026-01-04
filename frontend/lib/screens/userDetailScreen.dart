import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/models/discovery.dart';
import 'package:frontend/services/api.service.dart';
import 'package:frontend/screens/imagePreviewScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:frontend/screens/storedImageScreen.dart';

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
  List<dynamic> myGarden = []; // NEW: Adopted plants
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
      final gardenFuture = ApiService.getMyGarden(token); // NEW

      final results = await Future.wait([
        profileFuture, 
        discoveriesFuture, 
        historyFuture,
        gardenFuture
      ]);
      
      final profileData = results[0] as Map<String, dynamic>?;
      final discoveriesList = results[1] as List<dynamic>;
      final historyList = results[2] as List<dynamic>;
      final gardenList = results[3] as List<dynamic>;

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
            "plantId": d['plant']?['id'], 
            "careSchedule": (d['plant']?['tasks'] != null && (d['plant']['tasks'] as List).isNotEmpty)
                ? d['plant']['tasks']
                : [
                    {
                      "taskName": "Watering",
                      "action": "WATER",
                      "frequencyDays": 2,
                      "xpReward": 15,
                      "instruction": "Keep soil moist but not waterlogged.",
                      "difficulty": "Easy",
                      "timeOfDay": "Morning"
                    }
                  ], 
            "health": {
              "score": d['plant']?['healthScore'] ?? 0, 
              "status": d['plant']?['status'] ?? "Check Details"
            },
            "confidence": d['aiConfidence'] ?? d['confidence'] ?? 1.0,
            "imageSourceConfidence": {
               "realPlant": d['aiConfidence'] ?? d['confidence'] ?? 1.0,
               "screenOrPhoto": 1.0 - ((d['aiConfidence'] ?? d['confidence'] ?? 1.0) as num).toDouble(),
            },
          },
        );
      }).toList();

      if (mounted) {
        setState(() {
          if (profileData != null) {
            userName = profileData['username'] ?? user.displayName ?? "Explorer";
            userXp = profileData['xp'] ?? 0;
            userLevel = profileData['level'] ?? 1;
            userPhoto = user.photoURL;
          }
          discoveries = mappedDiscoveries;
          xpHistory = historyList;
          myGarden = gardenList; // NEW
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }
  
  // Verify Task Logic
  Future<void> _verifyTask(String plantId, String taskId) async {
    final picker = ImagePicker();
    
    // 1. Choose Source
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Colors.greenAccent),
              title: const Text("Take a Photo", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Colors.blueAccent),
              title: const Text("Choose from Gallery", style: TextStyle(color: Colors.white)),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    // 2. Pick Image
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile == null) return;

    // 3. Show Loading SnackBar
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black)
            ),
            SizedBox(width: 16),
            Text("Verifying with AI...", style: TextStyle(color: Colors.black)),
          ],
        ),
        backgroundColor: Colors.white,
        duration: Duration(minutes: 1), // Persist until dismissed manually
      ),
    );

    try {
      final user = FirebaseAuth.instance.currentUser;
      final token = await user?.getIdToken();

      if (token == null) throw Exception("Auth Error");

      final success = await ApiService.verifyCareTask(
        plantId: plantId,
        firebaseToken: token,
        imageFile: File(pickedFile.path),
        taskId: taskId,
      );
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide Loading

      if (success) {
        // Show Success SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.celebration, color: Colors.white),
                SizedBox(width: 12),
                Text("Success! +10 XP 🎉", style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 4),
          ),
        );
        
        // Refresh data 
        setState(() => isLoading = true); 
        await _loadUserData(); 
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar(); // Hide Loading

      // Show Error SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(child: Text("Verification Failed: ${e.toString().replaceAll("Exception: ", "")}")),
            ],
          ),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E1E), // Dark theme matching preview
      body: Stack(
        children: [
          // Background Gradient (Fixed behind scroll)
          Positioned.fill(
             child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF0F2027), Color(0xFF203A43), Color(0xFF2C5364)],
                ),
              ),
            ),
          ),
          
          isLoading 
            ? const Center(child: CircularProgressIndicator(color: Colors.greenAccent))
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
                        
                        // NEW: Adopted Plants Section
                        if (myGarden.isNotEmpty) ...[
                          const SizedBox(height: 40),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              "My Adopted Plants 🌿",
                              style: TextStyle(
                                color: Colors.greenAccent,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _buildGardenSection(),
                        ],
                        
                        const SizedBox(height: 40),
                        const Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            "All Discoveries",
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
                          style: TextStyle(color: Colors.white.withOpacity(0.5)),
                        ),
                      ),
                    ),
                  )

                : SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final discovery = discoveries[index];
                      return _buildPlantCard(discovery);
                    }, childCount: discoveries.length),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.9,
                    ),
                  ),
                ),

              if (xpHistory.isNotEmpty) ...[
                // ... (History header kept same)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: const Text(
                      "XP History",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final item = xpHistory[index];
                      final isDiscovery = item['type'] == 'DISCOVERY';
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.white.withOpacity(0.1)),
                        ),
                        child: Row(
                          children: [
                             Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: (isDiscovery ? Colors.green : Colors.blue).withOpacity(0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                isDiscovery ? Icons.camera_alt : Icons.water_drop,
                                color: isDiscovery ? Colors.greenAccent : Colors.lightBlueAccent,
                                size: 20,
                              ),
                            ),
                             const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item['title'] ?? "Activity",
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                  Text(
                                    item['date'] != null 
                                      ? DateTime.parse(item['date']).toLocal().toString().split(' ')[0] 
                                      : "",
                                    style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                             Text(
                              "+${item['xp']} XP",
                              style: const TextStyle(
                                color: Colors.amber,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: xpHistory.length,
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 50)),
              ],
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
                child: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // NEW: Build Garden Section
  Widget _buildGardenSection() {
    return Column(
      children: myGarden.map((plant) {
        final tasks = plant['tasks_due'] as List<dynamic>? ?? [];
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Plant Header
              Row(
                children: [
                   Container(
                     padding: const EdgeInsets.all(8),
                     decoration: BoxDecoration(
                       color: Colors.greenAccent.withOpacity(0.1),
                       shape: BoxShape.circle,
                     ),
                     child: const Icon(Icons.local_florist, color: Colors.greenAccent),
                   ),
                   const SizedBox(width: 12),
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           plant['name'] ?? "My Plant",
                           style: const TextStyle(
                             color: Colors.white,
                             fontWeight: FontWeight.bold,
                             fontSize: 18,
                           ),
                         ),
                         Text(
                           "🔥 ${plant['streak'] ?? 0} Day Streak • Health: ${plant['health']}%",
                           style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 13),
                         ),
                       ],
                     ),
                   ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Tasks List
              if (tasks.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white10,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                      SizedBox(width: 10),
                      Text(
                        "All caught up! No tasks due.",
                        style: TextStyle(color: Colors.white70),
                      ),
                    ],
                  ),
                )
              else
                Column(
                  children: tasks.map((task) => _buildTaskItem(task, plant['plant_id'])).toList(),
                ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildTaskItem(dynamic task, String plantId) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        children: [
          Icon(
            _getActionIcon(task['action']), // Helper needed
            color: Colors.orangeAccent,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['taskName'] ?? "Care Task",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                   "+${task['xpReward']} XP",
                   style: const TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () => _verifyTask(plantId, task['id'] ?? ""),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.greenAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            child: const Text("Verify"),
          ),
        ],
      ),
    );
  }

  IconData _getActionIcon(String? action) {
     switch (action) {
       case "WATER": return Icons.water_drop;
       case "FERTILIZE": return Icons.science;
       case "PRUNE": return Icons.content_cut;
       case "SUNLIGHT": return Icons.wb_sunny;
       default: return Icons.task_alt;
     }
  }

  // ... (Keep existing _buildProfileHeader and _buildStatsRow and _buildPlantCard)
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
              )
            ],
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundColor: Colors.grey[800],
            backgroundImage: userPhoto != null ? NetworkImage(userPhoto!) : null,
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
          _buildStatItem("Plants", "${discoveries.length}", Icons.local_florist, Colors.green),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
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

  Widget _buildPlantCard(Discovery discovery) {
     // ... (Keep implementation, same as before)
     final data = discovery.plantData;
    String displayName = "Unidentified Plant";
    if (data['canonicalName']?.toString().isNotEmpty == true) {
      displayName = data['canonicalName'];
    } else if (data['commonName']?.toString().isNotEmpty == true) {
      displayName = data['commonName'];
    }
    
    return GestureDetector(
    onTap: () async {
      // Hybrid Loading: Try to find local cached data first for "Perfect" fidelity
      Map<String, dynamic>? finalData = discovery.plantData;
      String finalImagePath = discovery.imagePath;

      try {
        final prefs = await SharedPreferences.getInstance();
        final localList = prefs.getStringList('discoveries') ?? [];
        
        // Find matching plantId in local storage
        final targetId = discovery.plantData['plantId'];
        if (targetId != null) {
          for (var item in localList) {
            final localJson = json.decode(item);
            final localPlantData = localJson['plantData'];
            
            // Check ID match
            if (localPlantData != null && localPlantData['plantId'] == targetId) {
              print("📱 Found local cache for $targetId! Using high-res data.");
              finalData = localPlantData;
              // Optional: Use local image path if it exists for faster load
              if (await File(localJson['imagePath']).exists()) {
                finalImagePath = localJson['imagePath'];
              }
              break;
            }
          }
        }
      } catch (e) {
        print("Local cache lookup failed: $e");
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ImagePreviewScreen(
            imagePath: finalImagePath,
            existingData: finalData, 
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
                color: Colors.black.withOpacity(0.2), 
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
                
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                      ),
                    ),
                  ),
                ),

                Positioned(
                  bottom: 10, left: 12, right: 12,
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        decoration: TextDecoration.none, 
                      ),
                    ),
                  ],
                ),
              ),

                // Confidence Warning
                if ((data['confidence'] as num? ?? 1.0) < 0.8)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.priority_high, color: Colors.redAccent, size: 20),
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
