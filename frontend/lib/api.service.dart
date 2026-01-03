import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:3000"; 

  static Future<void> syncUserWithBackend(String firebaseToken) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'), // The route we created earlier
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseToken', // sending the token!
        },
      );

      if (response.statusCode == 200) {
        print("✅ Backend Sync Success: ${response.body}");
      } else {
        print("Backend Sync Failed: ${response.body}");
      }
    } catch (e) {
      print(" Connection Error: $e");
    }
  }
}