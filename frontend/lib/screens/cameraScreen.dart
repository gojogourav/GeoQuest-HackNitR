// ignore_for_file: unused_field

import 'dart:io';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:frontend/main.dart';
import 'package:path_provider/path_provider.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  bool _isInitialized = false;
  bool _isCapturing = false;

  @override
  void initState() {
    super.initState();

    _controller = CameraController(
      cameras.first,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    _controller.initialize().then((_) {
      if (!mounted) return;
      setState(() => _isInitialized = true);
    });
  }

  Future<void> takePicture() async {
    if (_isCapturing || !_controller.value.isInitialized) return;
    _isInitialized = true;

    try {
      await _controller.pausePreview();
      final XFile file = await _controller.takePicture();
      final dir = await getApplicationDocumentsDirectory();
      final savedImage = File(
        '${dir.path}/${DateTime.now().microsecondsSinceEpoch}',
      );
      await File(file.path).copy(savedImage.path);
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
      Navigator.pop(context, savedImage.path);
    } finally {
      _isCapturing = false;
      if (_controller.value.isInitialized) {
        await _controller.resumePreview();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: Colors.white),
              SizedBox(height: 10),
              AutoSizeText(
                "Preparing camera...",
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
      );
    }

    final double scanSize = MediaQuery.of(context).size.width * 0.75;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          /// 📷 Camera Preview
          Positioned.fill(child: CameraPreview(_controller)),

          /// 🌑 Dark overlay
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.55)),
          ),

          /// 🔲 Scanner cut-out
          Center(
            child: Container(
              width: scanSize,
              height: scanSize,
              decoration: BoxDecoration(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.greenAccent, width: 2),
              ),
              child: Stack(children: const [ScanLineAnimation()]),
            ),
          ),

          /// 📝 Instruction
          Positioned(
            top: 80,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Text(
                  "Scan Plant",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  "Align the plant inside the square",
                  style: TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),

          /// 📸 Capture Button
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Center(
              child: GestureDetector(
                onTap: takePicture,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Color(0xFF6FCF97), Color(0xFF27AE60)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.green.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScanLineAnimation extends StatefulWidget {
  const ScanLineAnimation({super.key});

  @override
  State<ScanLineAnimation> createState() => _ScanLineAnimationState();
}

class _ScanLineAnimationState extends State<ScanLineAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Positioned(
          top: _controller.value * 220,
          left: 0,
          right: 0,
          child: Container(
            height: 2,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.transparent,
                  Colors.greenAccent,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
