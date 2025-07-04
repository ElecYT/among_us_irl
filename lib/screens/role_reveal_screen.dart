import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'action_phase_screen.dart';

class RoleRevealScreen extends StatelessWidget {
  final String roomCode;
  final String playerName;

  const RoleRevealScreen({
    required this.roomCode,
    required this.playerName,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('games').doc(roomCode);

    return MaterialApp(
        theme: ThemeData(
        primarySwatch: Colors.grey, // Dark theme base color
        brightness: Brightness.dark, // Setting the brightness to dark
        scaffoldBackgroundColor: Colors.black87, // Dark background color for the whole app
        cardColor: Colors.blueGrey[900], // Color of cards like dialogs or bottom sheets
        textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white), // Text color in light mode
    bodySmall: TextStyle(color: Colors.white70),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white70),
    titleMedium: TextStyle(color: Colors.white70),
    titleSmall: TextStyle(color: Colors.white70),
    ),
    ),
    home: Scaffold(
      appBar: AppBar(
        title: Text('Role Reveal - $playerName'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: roomRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          if (players.isEmpty) {
            return const Center(child: Text('No players found in this room.'));
          }

          final currentPlayer = players.firstWhere(
                (p) => p['name'] == playerName,
            orElse: () => {},
          );

          final role = currentPlayer['role']?.toString() ?? 'Unknown';

          // Display role prominently
          final roleColor = role == 'imposter' ? Colors.red : Colors.blue;

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'You are the',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 10),
                Text(
                  role.toUpperCase(),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                    color: roleColor,
                  ),
                ),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                    // Proceed to Action Phase
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ActionPhaseScreen(
                          roomCode: roomCode,
                          playerName: playerName,
                        ),
                      ),
                    );
                  },
                  child: const Text('Start'),
                ),
              ],
            ),
          );
        },
      ),
    ),
    );
  }
}