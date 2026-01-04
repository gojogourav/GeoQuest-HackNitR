import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

class ApiService {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
  static String get baseUrl {
    if (Platform.isAndroid) {
       // If using 'adb reverse tcp:3000 tcp:3000', use localhost/127.0.0.1
       // If standard emulator without reverse, 10.0.2.2 is needed.
       // We can try to prefer localhost if we assume adb reverse is active.
       return "http://127.0.0.1:3000/api";
    }
    return "http://localhost:3000/api";
  }



  static Future<Map<String, dynamic>?> syncUserWithBackend(String firebaseToken) async {
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
        // print("✅ Backend Sync Success: ${response.body}"); // Reduce noise
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'];
      } else {
        print("❌ Backend Sync Failed (${response.statusCode}): ${response.body}");
        return null;
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
      return null;
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
    
    // Read file and convert to Base64
    final bytes = await File(imagePath).readAsBytes();
    final base64Image = base64Encode(bytes);

    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${firebaseToken.trim()}',
      },
      body: jsonEncode({
        'image': base64Image,
        'latitude': latitude,
        'longitude': longitude,
        'district': district,
        'state': state,
        'country': country,
      }),
    ).timeout(const Duration(seconds: 60)); // Increased timeout for large payload

    return response;
  }
  static Future<List<dynamic>> getUserDiscoveries(String firebaseToken) async {
    try {
      final url = Uri.parse('$baseUrl/discover/my-discoveries');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${firebaseToken.trim()}',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['data'] ?? [];
      } else {
        print("❌ Fetch Discoveries Failed (${response.statusCode}): ${response.body}");
        return [];
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getLeaderboard(String firebaseToken) async {
    try {
      final url = Uri.parse('$baseUrl/user/leaderboard');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${firebaseToken.trim()}',
        },
      );
      //...
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  static Future<List<dynamic>> getXPHistory(String firebaseToken) async {
    try {
      final url = Uri.parse('$baseUrl/user/xp-history');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${firebaseToken.trim()}',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['history'] ?? [];
      } else {
        print("❌ Fetch XP History Failed (${response.statusCode}): ${response.body}");
        return [];
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
      return [];
    }
  }

  // --- PLANT CARE & GARDEN ---

  static Future<List<dynamic>> getMyGarden(String firebaseToken) async {
    try {
      final url = Uri.parse('$baseUrl/user/garden');
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $firebaseToken',
        },
      );

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['garden'] ?? [];
      } else {
        print("❌ Fetch Garden Failed (${response.statusCode}): ${response.body}");
        return [];
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
      return [];
    }
  }

  static Future<Map<String, dynamic>?> getCareTasks(String plantId, String firebaseToken) async {
      try {
        final url = Uri.parse('$baseUrl/caretaker/tasks/$plantId');
        final response = await http.get(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer ${firebaseToken.trim()}',
          },
        );

        if (response.statusCode == 200) {
          return json.decode(response.body);
        } else {
          print("❌ Fetch Tasks Failed (${response.statusCode}): ${response.body}");
          return null;
        }
      } catch (e) {
        print("⚠️ Connection Error: $e");
        return null;
      }
  }

  static Future<bool> adoptPlant({
    required String plantId,
    required List<dynamic> careSchedule,
    required String firebaseToken,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/caretaker/adopt');
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${firebaseToken.trim()}',
        },
        body: json.encode({
          "plantId": plantId,
          "careSchedule": careSchedule,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201 || response.statusCode == 409) {
        return true;
      } else {
        throw Exception("Failed (${response.statusCode}): ${response.body}");
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
      // Rethrow to let UI handle it
      throw e;
    }
  }

  static Future<bool> verifyCareTask({
    required String plantId,
    required String firebaseToken,
    required File imageFile,
    String? taskId,
  }) async {
    try {
      final uri = Uri.parse("$baseUrl/care/verify");
      final request = http.MultipartRequest("POST", uri);

      request.headers['Authorization'] = 'Bearer $firebaseToken';
      request.fields['plantId'] = plantId;
      if (taskId != null) {
        request.fields['taskId'] = taskId;
      }

      final multipartFile = await http.MultipartFile.fromPath(
        'photo',
        imageFile.path,
      );
      request.files.add(multipartFile);

      final response = await request.send().timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        throw Exception("Request Timed Out. AI is taking too long.");
      },
    );

      if (response.statusCode == 200) {
         final respStr = await response.stream.bytesToString();
         print("✅ Care Verified: $respStr");
         return true;
      } else {
         final respStr = await response.stream.bytesToString();
         throw Exception("Failed (${response.statusCode}): $respStr");
      }
    } catch (e) {
      print("⚠️ Connection Error: $e");
      throw e;
    }
  }
}