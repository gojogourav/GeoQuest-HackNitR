import 'dart:io';
import 'package:flutter/material.dart';
import 'package:frontend/screens/imagePreviewScreen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StoredImageScreen extends StatefulWidget {
  const StoredImageScreen({super.key});

  @override
  State<StoredImageScreen> createState() => _StoredImageScreenState();
}

class _StoredImageScreenState extends State<StoredImageScreen> {
  List<String> imagePaths = [];

  @override
  void initState() {
    super.initState();
    loadImages();
  }

  Future<void> loadImages() async {
    final prefs = await SharedPreferences.getInstance();
    final paths = prefs.getStringList('images') ?? [];

    imagePaths = paths
        .where((p) => File(p).existsSync())
        .toList()
        .reversed
        .toList();

    await prefs.setStringList('images', imagePaths);
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F6),
      body: CustomScrollView(
        slivers: [
          /// 🌿 Sliver App Bar (Header)
          SliverAppBar(
            expandedHeight: 220,
            pinned: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: FlexibleSpaceBar(
              title: const Text(
                "My Scanned Plants",
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              background: Stack(
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFA8E6CF), Color(0xFFEFFAF3)],
                      ),
                    ),
                  ),
                  Center(
                    child: Icon(
                      Icons.eco_outlined,
                      size: 200,
                      color: const Color.fromARGB(
                        255,
                        94,
                        188,
                        98,
                      ).withOpacity(0.3),
                    ),
                  ),
                  Positioned(
                    top: MediaQuery.of(context).size.width * 0.25,
                    left: MediaQuery.of(context).size.width * 0.05,
                    child: Text(
                      imagePaths.isEmpty ? "" : "${imagePaths.length} Pictures",
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content
          imagePaths.isEmpty
              ? SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        //Icon(Icons.eco_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text(
                          "No images found",
                          style: TextStyle(fontSize: 16, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : SliverPadding(
                  padding: const EdgeInsets.all(16),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final path = imagePaths[index];

                      return GestureDetector(
                        onTap: () async {
                          final deleted = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  ImagePreviewScreen(imagePath: path),
                            ),
                          );

                          if (deleted == true) {
                            loadImages();
                          }
                        },
                        child: Hero(
                          tag: 'image_$path',
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 12,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: Image.file(File(path), fit: BoxFit.cover),
                            ),
                          ),
                        ),
                      );
                    }, childCount: imagePaths.length),
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
    );
  }
}
