import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/api.service.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  List<Map<String, dynamic>> _users = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchLeaderboard();
  }

  Future<void> _fetchLeaderboard() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      
      final token = await user.getIdToken();
      final data = await ApiService.getLeaderboard(token!); // Method we just added

      if (data != null && data['leaderboard'] != null) {
        final List<dynamic> rawList = data['leaderboard'];
        
        setState(() {
          _users = rawList.asMap().entries.map((entry) {
            final idx = entry.key;
            final item = entry.value;
            return {
              'name': item['username'] ?? "Unknown",
              'score': item['xp'] ?? 0,
              'avatar': item['photoUrl'],
              'rank': idx + 1,
            };
          }).toList();
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print("Error fetching leaderboard: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          "Leaderboard",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
        centerTitle: true,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromARGB(255, 3, 21, 8),
              Color.fromARGB(255, 1, 6, 3),
            ],
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: 100), // Space for AppBar
            
            if (_isLoading)
              const Expanded(child: Center(child: CircularProgressIndicator(color: Colors.greenAccent)))
            else if (_users.isEmpty)
              const Expanded(child: Center(child: Text("No explorers yet!", style: TextStyle(color: Colors.white70))))
            else if (_users.length < 5)
              // Simple List View for < 5 users
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(top: 20, bottom: 100),
                  itemCount: _users.length,
                  itemBuilder: (context, index) {
                    return _buildListItem(_users[index]);
                  },
                ),
              )
            else ...[
              // Top 3 Podium
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    // 2nd Place
                    if (_users.length > 1) 
                      _buildPodiumItem(_users[1], 80, Colors.grey.shade400)
                    else 
                      const SizedBox(width: 80),

                    // 1st Place (Always exists if we are in this block)
                    _buildPodiumItem(_users[0], 110, Colors.amber), 

                    // 3rd Place
                    if (_users.length > 2)
                      _buildPodiumItem(_users[2], 80, Colors.brown.shade400)
                    else
                      const SizedBox(width: 80),
                  ],
                ),
              ),
              const SizedBox(height: 30),
            
              // Rest of the list
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                      child: ListView.builder(
                        padding: const EdgeInsets.only(top: 20, bottom: 100),
                        // Handle cases where we have fewer than 3 users
                        itemCount: (_users.length > 3) ? _users.length - 3 : 0,
                        itemBuilder: (context, index) {
                          // If we have >3 users, show them. 
                          // The first 3 are on podium, so we start from index 3
                          final user = _users[index + 3];
                          return _buildListItem(user);
                        },
                      ),
                    ),
                  ),
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumItem(
    Map<String, dynamic> user,
    double size,
    Color ringColor,
  ) {
    return Column(
      children: [
        CircleAvatar(
          radius: size / 2,
          backgroundColor: ringColor,
          child: CircleAvatar(
            radius: size / 2 - 3,
            backgroundColor: Colors.grey[800],
            child: Text(
              user['name'][0],
              style: TextStyle(
                color: ringColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          user['name'],
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        Text(
          "${user['score']}",
          style: TextStyle(color: ringColor, fontSize: 14),
        ),
        const SizedBox(height: 10),
        Container(
          height: user['rank'] == 1 ? 40 : 25,
          width: 30,
          decoration: BoxDecoration(
            color: ringColor.withOpacity(0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
            boxShadow: [
              BoxShadow(
                color: ringColor.withOpacity(0.4),
                blurRadius: 10,
                offset: const Offset(0, 0),
              ),
            ],
          ),
          child: Center(
            child: Text(
              "${user['rank']}",
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListItem(Map<String, dynamic> user) {
    final bool isTop = user['rank'] == 1;
    
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isTop ? Colors.amber.withOpacity(0.1) : Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: isTop 
            ? Border.all(color: Colors.amber, width: 2)
            : Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: isTop ? [
          BoxShadow(
            color: Colors.amber.withOpacity(0.4),
            blurRadius: 12,
            spreadRadius: 1,
          )
        ] : [],
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            alignment: Alignment.center,
            child: isTop 
              ? const Text("👑", style: TextStyle(fontSize: 20))
              : Text(
                  "${user['rank']}",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
          ),
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 20,
            backgroundColor: isTop ? Colors.amber : Colors.blueGrey.shade800,
            child: Text(
              user['name'][0],
              style: TextStyle(
                color: isTop ? Colors.black : Colors.white,
                fontWeight: FontWeight.bold
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              user['name'],
              style: TextStyle(
                color: isTop ? Colors.amberAccent : Colors.white,
                fontSize: 16,
                fontWeight: isTop ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ),
          Text(
            "${user['score']} pts",
            style: TextStyle(
              color: isTop ? Colors.amber : Colors.greenAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
