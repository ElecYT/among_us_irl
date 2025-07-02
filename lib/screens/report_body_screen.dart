import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'final_screen.dart'; // Ensure this import is correct and points to your final screen file

class ReportBodyScreen extends StatefulWidget {
  final String? roomCode;
  final String? playerName;

  const ReportBodyScreen({
    required this.roomCode,
    required this.playerName,
    super.key,
  });

  @override
  State<ReportBodyScreen> createState() => _ReportBodyScreenState();

// In ReportBodyScreen class
// void checkGameEnd(String roomCode) async { // OLD
    void checkGameEnd(BuildContext context, String roomCode) async { // NEW: Add context parameter
      DocumentReference gameRef = FirebaseFirestore.instance
          .collection('games')
          .doc(roomCode);

      final doc = await gameRef.get();
      // Ensure 'doc.exists' before trying to get data
      if (!doc.exists || doc.data() == null) {
        print("Game document not found or has no data for room: $roomCode");
        return;
      }
      final data = doc.data() as Map<String, dynamic>;
      final players = List<Map<String, dynamic>>.from(data['players'] ?? []); // Add null check for safety
      int crewmateCount = 0;
      int imposterCount = 0;
      for (var player in players) {
        // Make sure 'role' exists and is a string
        if (player['role'] is String) {
          if (player['role'] == 'crewmate') {
            crewmateCount++;
          } else if (player['role'] == 'imposter') {
            imposterCount++;
          }
        }
      }

      // Check if the widget is still mounted before navigating
      // This requires 'checkGameEnd' to be called from the State object
      // or for you to have a way to check mounted status if called differently.
      // For now, let's assume if context is valid, it's okay to try.

      if (crewmateCount == 0 || imposterCount == 0) {
        // Ensure context is still valid if this is a long async operation
        // (though in this specific case, it might be fine directly after await)
        if (Navigator.of(context).mounted) { // Good practice
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FinalScreen(
                    isCrewWinner: crewmateCount > imposterCount,
                    message: '${crewmateCount > imposterCount
                        ? "Crewmates"
                        : "Imposters"} won the game!',
                  ),
            ),
          );
        }
      } else if (imposterCount > 0 && imposterCount == crewmateCount) { // Ensure imposterCount > 0 for this condition
        if (Navigator.of(context).mounted) { // Good practice
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  FinalScreen(
                    isCrewWinner: false, // Imposters win in a tie where imposters are present
                    message: 'Imposters won the game!',
                  ),
            ),
          );
        }
      }
    }
  }

class _ReportBodyScreenState extends State<ReportBodyScreen> {
  String? selectedDeadPlayer;
  final TextEditingController locationController = TextEditingController();
  String? error;

  late DocumentReference gameRef;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance
        .collection('games')
        .doc(widget.roomCode);
  }

  Future<void> submitReport() async {
    if (selectedDeadPlayer == null || locationController.text.trim().isEmpty) {
      setState(() => error = 'Please enter a location/valid player.');
      return;
    }

    final roomRef = FirebaseFirestore.instance
        .collection('games')
        .doc(widget.roomCode);

    final doc = await roomRef.get();
    final data = doc.data() as Map<String, dynamic>;
    final players = List<Map<String, dynamic>>.from(data['players']);

    // Update the dead player's status to 'dead'
    final updatedPlayers = players.map((p) {
      if (p['name'] == selectedDeadPlayer) {
        return {...p, 'role': 'dead'};
      }
      return p;
    }).toList();

    await roomRef.update({
      'players': updatedPlayers,
      'report': {
        'reporter': widget.playerName,
        'victim': selectedDeadPlayer,
        'location': locationController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      },
      'phase': 'meeting',
      'votes': {}, // Reset any previous votes
    });

    if (!mounted) return;

    Navigator.pop(context); // Optional: return to main screen to await meeting transition
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
          title: Text('Report Body - ${widget.playerName}'),
          centerTitle: true,
          leading: IconButton(
            icon: Icon(Icons.arrow_back), // Use any icon you prefer or a custom one
            onPressed: () {
              Navigator.pop(context); // This will navigate back to the previous screen
            },
          ),
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: gameRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final data = snapshot.data!.data() as Map<String, dynamic>;
            final players = List<Map<String, dynamic>>.from(data['players']);
            final currentPlayer = players.firstWhere((p) => p['name'] == widget.playerName);

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  const Text(
                    'Who is the dead player?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ...players.map((player) {
                    final name = player['name'];
                    return RadioListTile<String>(
                      title: Text(name),
                      value: name,
                      groupValue: selectedDeadPlayer,
                      onChanged: (val) {
                        setState(() => selectedDeadPlayer = val);
                      },
                    );
                  }),
                  const SizedBox(height: 20),
                  TextField(
                    controller: locationController,
                    decoration: const InputDecoration(
                      labelText: 'Where was the body?',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: submitReport,
                    child: const Text('Submit Report'),
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