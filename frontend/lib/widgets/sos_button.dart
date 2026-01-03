import 'dart:async';
import 'package:flutter/material.dart';
import 'package:vibration/vibration.dart';

class SOSButton extends StatefulWidget {
  final VoidCallback onSOS;
  final Duration duration;

  const SOSButton({
    super.key,
    required this.onSOS,
    this.duration = const Duration(seconds: 30),
  });

  @override
  State<SOSButton> createState() => _SOSButtonState();
}

class _SOSButtonState extends State<SOSButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  Timer? _timer;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _triggerSOS();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _startSOS() async {
    setState(() {
      _isPressed = true;
    });
    _controller.forward();
    
    // Start vibration
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(duration: 30000); // Vibrate for 30s
    }
  }

  void _cancelSOS() {
    if (_controller.status == AnimationStatus.completed) return; // Already sent
    
    setState(() {
      _isPressed = false;
    });
    _controller.reset();
    Vibration.cancel(); // Stop vibration
  }

  void _triggerSOS() {
    setState(() {
      _isPressed = false;
    });
    Vibration.cancel(); // Stop vibration
    Vibration.vibrate(duration: 500); // Success feedback
    widget.onSOS();
    _controller.reset();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPressStart: (_) => _startSOS(),
      onLongPressEnd: (_) => _cancelSOS(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Pulse Effect / Background Ring
          if (_isPressed)
            SizedBox(
              width: 80,
              height: 80,
              child: CircularProgressIndicator(
                value: _controller.value, // This has to be animatedBuilder if used directly
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.redAccent),
                strokeWidth: 6,
                backgroundColor: Colors.red.withOpacity(0.2),
              ),
            ),
            
          // Using AnimatedBuilder to correctly animate the progress ring
          if (_isPressed)
             AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return SizedBox(
                  width: 80,
                  height: 80,
                  child: CircularProgressIndicator(
                    value: _controller.value,
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                    strokeWidth: 6,
                    backgroundColor: Colors.red.withOpacity(0.2),
                  ),
                );
              },
            ),

          // The Button Itself
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: _isPressed ? Colors.red : Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
                if (_isPressed)
                   BoxShadow(
                    color: Colors.red.withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: Icon(
              Icons.sos,
              color: _isPressed ? Colors.white : Colors.red,
              size: 30,
            ),
          ),
          
          if (_isPressed)
            Positioned(
              top: -40,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(12)
                ),
                child: const Text(
                  "Hold for Emergency",
                  style: TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
            )
        ],
      ),
    );
  }
}
