import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:frontend/services/api.service.dart';
import 'package:frontend/screens/plant_care_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class MyGardenScreen extends StatefulWidget {
  const MyGardenScreen({super.key});

  @override
  State<MyGardenScreen> createState() => _MyGardenScreenState();
}

class _MyGardenScreenState extends State<MyGardenScreen> {
  bool _isLoading = true;
  List<dynamic> _garden = [];

  @override
  void initState() {
    super.initState();
    _fetchGarden();
  }

  Future<void> _fetchGarden() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final token = await user.getIdToken();
    if (token == null) return;

    final data = await ApiService.getMyGarden(token);
    if (mounted) {
      setState(() {
        _garden = data;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(
          "My Garden",
          style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        leading: const BackButton(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _garden.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       const Icon(Icons.yard_outlined, size: 64, color: Colors.grey),
                       const SizedBox(height: 16),
                       Text("Your garden is empty.", style: TextStyle(color: Colors.white.withOpacity(0.6))),
                       const SizedBox(height: 8),
                       Text("Discover plants to adopt them!", style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 12)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _garden.length,
                  itemBuilder: (context, index) {
                    final plant = _garden[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => PlantCareScreen(
                              plantId: plant['plant_id'],
                              plantName: plant['name'] ?? "Unknown Plant",
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.green.withOpacity(0.3)),
                        ),
                        child: Row(
                          children: [
                            Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                    color: Colors.green.withOpacity(0.2),
                                    shape: BoxShape.circle,
                                ),
                                child: const Icon(Icons.local_florist, color: Colors.greenAccent),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    plant['name'] ?? "Plant",
                                    style: GoogleFonts.outfit(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                      children: [
                                          Icon(Icons.monitor_heart, color: Colors.redAccent, size: 14),
                                          const SizedBox(width: 4),
                                          Text("${plant['health'] ?? 0}% Health", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                          const SizedBox(width: 12),
                                          Icon(Icons.local_fire_department, color: Colors.orange, size: 14),
                                          const SizedBox(width: 4),
                                          Text("${plant['streak'] ?? 0} Day Streak", style: TextStyle(color: Colors.white70, fontSize: 12)),
                                      ],
                                  )
                                ],
                              ),
                            ),
                            const Icon(Icons.arrow_forward_ios, color: Colors.white54, size: 16),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
