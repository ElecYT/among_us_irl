import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'lobby_screen.dart';

class JoinGameScreen extends StatefulWidget {
  const JoinGameScreen({super.key});

  @override
  State<JoinGameScreen> createState() => _JoinGameScreenState();
}

class _JoinGameScreenState extends State<JoinGameScreen> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  String? errorMessage;
  bool isLoading = false;

  Future<void> joinRoom() async {
    final roomCode = _codeController.text.trim().toUpperCase();
    final playerName = _nameController.text.trim();

    if (roomCode.length != 6) {
      setState(() => errorMessage = 'Room code must be 6 characters.');
      return;
    }
    if (playerName.isEmpty) {
      setState(() => errorMessage = 'Please enter a name.');
      return;
    }

    setState(() {
      errorMessage = null;
      isLoading = true;
    });

    final roomRef = FirebaseFirestore.instance.collection('games').doc(roomCode);
    final doc = await roomRef.get();

    if (!doc.exists) {
      setState(() {
        isLoading = false;
        errorMessage = 'Room not found.';
      });
      return;
    }

    final data = doc.data() as Map<String, dynamic>;
    final phase = data['phase'] ?? 'waiting';
    if (phase != 'waiting') {
      setState(() {
        isLoading = false;
        errorMessage = 'Game already started. Please wait for a new room.';
      });
      return;
    }

    final List<Map<String, dynamic>> players = List<Map<String, dynamic>>.from(data['players'] ?? []);
    if (players.any((p) => p['name'].toString().toLowerCase() == playerName.toLowerCase())) {
      setState(() {
        isLoading = false;
        errorMessage = 'Name already in use in this lobby.';
      });
      return;
    }

    players.add({'name': playerName, 'role': 'undecided'});
    await roomRef.update({'players': players});

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => LobbyScreen(
          roomCode: roomCode,
          isHost: false,
          playerName: playerName,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        title: Text('Join Game'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back), // Use any icon you prefer or a custom one
          onPressed: () {
            Navigator.pop(context); // This will navigate back to the previous screen
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _codeController,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Enter Room Code',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.characters,
              maxLength: 6,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp('[A-Za-z0-9]')), UpperCaseTextFormatter()],
              onSubmitted: (_) => joinRoom(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              enabled: !isLoading,
              decoration: const InputDecoration(
                labelText: 'Enter Your Name',
                border: OutlineInputBorder(),
              ),
              maxLength: 20,
              onSubmitted: (_) => joinRoom(),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: isLoading ? null : joinRoom,
              child: isLoading
                  ? const SizedBox(
                height: 18,
                width: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
                  : const Text('Join'),
            ),
            if (errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
          ],
        ),
      ),
    ),
    );
  }
}

// For consistent room code uppercase entry
class UpperCaseTextFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    return newValue.copyWith(
      text: newValue.text.toUpperCase(),
      selection: newValue.selection,
    );
  }
}