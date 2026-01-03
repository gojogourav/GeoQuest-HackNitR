import 'package:http/http.dart' as http;
import 'dart:io' show Platform;
import 'package:http_parser/http_parser.dart';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get baseUrl {
    if (Platform.isAndroid) {
      return "http://10.0.2.2:3000/api";
    }
    return "http://localhost:3000/api";
  }

  static Future<void> syncUserWithBackend(String firebaseToken) async {
    try {
      final url = Uri.parse('$baseUrl/auth/login');
      print("🔌 Syncing with Backend: $url");

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseToken',
        },
      );

      if (response.statusCode == 200) {
        print("✅ Backend Sync Success: ${response.body}");
      } else {
        print("❌ Backend Sync Failed (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
    }
  }

  static Future<http.Response> scanPlant(
      String imagePath,
      String firebaseToken, {
      required double latitude,
      required double longitude,
      String? district,
      String? state,
      String? country,
  }) async {
    final uri = Uri.parse("$baseUrl/discover/scan");
    final request = http.MultipartRequest("POST", uri);

    request.headers['Authorization'] = 'Bearer $firebaseToken';

    final mimeType = imagePath.toLowerCase().endsWith(".png")
        ? MediaType("image", "png")
        : MediaType("image", "jpeg");

    request.files.add(
      await http.MultipartFile.fromPath(
        "photo",
        imagePath,
        contentType: mimeType,
      ),
    );

    request.fields['latitude'] = latitude.toString();
    request.fields['longitude'] = longitude.toString();
    if (district != null) request.fields['district'] = district;
    if (state != null) request.fields['state'] = state;
    if (country != null) request.fields['country'] = country;

    final streamedResponse = await request.send();
    return await http.Response.fromStream(streamedResponse);
  }
}