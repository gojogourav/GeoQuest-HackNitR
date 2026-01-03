import 'dart:ui';
import 'package:flutter/material.dart';

class LeaderboardPage extends StatefulWidget {
  const LeaderboardPage({super.key});

  @override
  State<LeaderboardPage> createState() => _LeaderboardPageState();
}

class _LeaderboardPageState extends State<LeaderboardPage> {
  // Mock Data
  final List<Map<String, dynamic>> _users = [
    {'name': 'Alex', 'score': 2400, 'avatar': '', 'rank': 1},
    {'name': 'Sarah', 'score': 2100, 'avatar': '', 'rank': 2},
    {'name': 'Mike', 'score': 1850, 'avatar': '', 'rank': 3},
    {'name': 'Emma', 'score': 1600, 'avatar': '', 'rank': 4},
    {'name': 'John', 'score': 1450, 'avatar': '', 'rank': 5},
    {'name': 'You', 'score': 1200, 'avatar': '', 'rank': 6}, // Current user
    {'name': 'David', 'score': 1100, 'avatar': '', 'rank': 7},
    {'name': 'Lisa', 'score': 900, 'avatar': '', 'rank': 8},
  ];

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
            // Top 3 Podium
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _buildPodiumItem(_users[1], 80, Colors.grey.shade400), // 2nd
                  _buildPodiumItem(_users[0], 110, Colors.amber), // 1st
                  _buildPodiumItem(_users[2], 80, Colors.brown.shade400), // 3rd
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
                      itemCount: _users.length - 3,
                      itemBuilder: (context, index) {
                        final user = _users[index + 3];
                        return _buildListItem(user);
                      },
                    ),
                  ),
                ),
              ),
            ),
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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            width: 30,
            alignment: Alignment.center,
            child: Text(
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
            backgroundColor: Colors.blueGrey.shade800,
            child: Text(
              user['name'][0],
              style: const TextStyle(color: Colors.white),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              user['name'],
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Text(
            "${user['score']} pts",
            style: const TextStyle(
              color: Colors.greenAccent,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
