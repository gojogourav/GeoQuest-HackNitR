import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/screens/home.dart';
import '../services/auth_service.dart'; // Import your AuthService file

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn() async {
    setState(() => _isLoading = true);

    try {
      // Call your fixed AuthService
      final userCredential = await AuthService().signInWithGoogle(context);

      if (mounted) {
        setState(() => _isLoading = false);
      }

      if (userCredential != null) {
        // Navigate to Home Page on success
        if (mounted) {
          Navigator.of(
            context,
          ).pushReplacement(MaterialPageRoute(builder: (_) => HomeScreen()));
        }
      } else {
        // Cancelled by user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sign in cancelled"),
              backgroundColor: Colors.orangeAccent,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Sign in failed: $e"),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine theme brightness for text colors
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF121212) : Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // --- Logo or App Icon ---
                Container(
                  height: 100,
                  width: 100,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Icon(
                    Icons.lock_person_rounded,
                    size: 48,
                    color: Colors.blueAccent,
                  ),
                ),

                const SizedBox(height: 32),

                // --- Welcome Text ---
                Text(
                  "Welcome Back",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Sign in to continue to your account",
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),

                const Spacer(),

                // --- Google Sign In Button ---
                _isLoading
                    ? const CircularProgressIndicator()
                    : SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: _handleGoogleSignIn,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.grey[800]
                                : Colors.white,
                            foregroundColor: isDark
                                ? Colors.white
                                : Colors.black87,
                            elevation: 0,
                            side: BorderSide(
                              color: isDark
                                  ? Colors.grey[700]!
                                  : Colors.grey[300]!,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Use an asset image here for the real Google logo
                              // Image.asset('assets/google_logo.png', height: 24),
                              const Icon(
                                Icons.g_mobiledata,
                                size: 32,
                                color: Colors.red,
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                "Continue with Google",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                const SizedBox(height: 48),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
