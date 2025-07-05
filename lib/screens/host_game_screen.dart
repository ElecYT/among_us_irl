import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'lobby_screen.dart';

class HostGameScreen extends StatefulWidget {
  const HostGameScreen({super.key});

  @override
  State<HostGameScreen> createState() => _HostGameScreenState();
}

class _HostGameScreenState extends State<HostGameScreen> {
  final TextEditingController _nameController = TextEditingController();
  late final String roomCode;
  String? errorMessage;
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    roomCode = _generateRoomCode();
  }

  String _generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }

  Future<void> createRoom() async {
    final playerName = _nameController.text.trim();
    if (playerName.isEmpty) {
      setState(() => errorMessage = 'Please enter a name.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final roomRef = FirebaseFirestore.instance
        .collection('games')
        .doc(roomCode);

    // Ensure no player collision on name in this code
    final doc = await roomRef.get();
    if (doc.exists) {
      final data = doc.data() as Map<String, dynamic>;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
      if (players.any(
        (p) => p['name'].toString().toLowerCase() == playerName.toLowerCase(),
      )) {
        setState(() {
          isLoading = false;
          errorMessage = 'Name already in use in this room.';
        });
        return;
      }
    }

    await roomRef.set({
      'code': roomCode,
      'created_at': DateTime.now(),
      'players': [
        {'name': playerName, 'role': 'undecided'},
      ],
      'phase': 'waiting',
      'imposter_count': 1,
    });

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => LobbyScreen(
          roomCode: roomCode,
          isHost: true,
          playerName: playerName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primarySwatch: Colors.grey, // Dark theme base color
        brightness: Brightness.dark, // Setting the brightness to dark
        scaffoldBackgroundColor:
            Colors.black87, // Dark background color for the whole app
        cardColor: Colors
            .blueGrey[900], // Color of cards like dialogs or bottom sheets
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
          title: const Text('Host Game'),
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back,
            ), // Use any icon you prefer or a custom one
            onPressed: () {
              Navigator.pop(
                context,
              ); // This will navigate back to the previous screen
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Room Code:', style: TextStyle(fontSize: 20)),
                const SizedBox(height: 10),
                Text(
                  roomCode,
                  style: const TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Share this code with your friends to join. You need to click the "create game" button before they may join.'),
                const SizedBox(height: 40),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Enter Your Name',
                    border: OutlineInputBorder(),
                  ),
                  maxLength: 20,
                  enabled: !isLoading,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isLoading ? null : createRoom,
                  child: isLoading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Game'),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
