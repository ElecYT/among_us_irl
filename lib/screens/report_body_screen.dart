import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'final_screen.dart';

// Standalone method (call from any screen to check end condition)
Future<void> checkGameEnd({
  required BuildContext context,
  required String roomCode,
  required String playerName,
  required bool isHost,
}) async {
  final gameRef = FirebaseFirestore.instance.collection('games').doc(roomCode);
  final doc = await gameRef.get();
  if (!doc.exists || doc.data() == null) return;
  final data = doc.data() as Map<String, dynamic>;
  final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
  int crewmateCount = 0;
  int imposterCount = 0;
  for (var player in players) {
    if (player['role'] == 'crewmate') crewmateCount++;
    if (player['role'] == 'imposter') imposterCount++;
  }

  // Victory logic: If only crewmates or imposters remain
  final gameOver = crewmateCount == 0 || imposterCount == 0 ||
      (imposterCount > 0 && imposterCount == crewmateCount);

  if (gameOver && Navigator.of(context).mounted) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => FinalScreen(
          roomCode: roomCode,
          playerName: playerName,
          isHost: isHost,
          isCrewmatesWin: crewmateCount > imposterCount,
        ),
      ),
          (_) => false,
    );
  }
}

class ReportBodyScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const ReportBodyScreen({
    required this.roomCode,
    required this.playerName,
    Key? key,
  }) : super(key: key);

  @override
  State<ReportBodyScreen> createState() => _ReportBodyScreenState();
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
      setState(() => error = 'Please enter a location and select a player.');
      return;
    }

    final doc = await gameRef.get();
    final data = doc.data() as Map<String, dynamic>;
    final players = List<Map<String, dynamic>>.from(data['players']);
    // Update the dead player's status to 'dead'
    final updatedPlayers = players.map((p) {
      if (p['name'] == selectedDeadPlayer) {
        return {...p, 'role': 'dead'};
      }
      return p;
    }).toList();

    await gameRef.update({
      'players': updatedPlayers,
      'report': {
        'reporter': widget.playerName,
        'victim': selectedDeadPlayer,
        'location': locationController.text.trim(),
        'timestamp': FieldValue.serverTimestamp(),
      },
      'phase': 'meeting',
      'votes': {}, // Reset previous votes
    });

    if (!mounted) return;
    Navigator.pop(context); // Go back, let phase-drive take over
  }

  @override
  Widget build(BuildContext context) {
    // Optionally call this statically at the top of 'build' in each phase screen:
    // checkGameEnd(context: context, roomCode: widget.roomCode, playerName: widget.playerName, isHost: /*...host logic...*/);

    return Scaffold(
      appBar: AppBar(
        title: Text('Report Body - ${widget.playerName}'),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final data = snapshot.data!.data() as Map<String, dynamic>;
          final players = List<Map<String, dynamic>>.from(data['players']);
          // Remove self from list of who can be reported (can't report yourself as dead)
          final reportablePlayers = players.where((p) => p['name'] != widget.playerName).toList();

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Text('Who is the dead player?', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                ...reportablePlayers.map((player) {
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
                if (error != null) Text(error!, style: const TextStyle(color: Colors.red)),
                ElevatedButton(
                  onPressed: submitReport,
                  child: const Text('Submit Report'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}