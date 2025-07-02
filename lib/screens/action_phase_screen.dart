import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_body_screen.dart';
import 'meeting_screen.dart';

class ActionPhaseScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  const ActionPhaseScreen({
    required this.roomCode,
    required this.playerName,
    super.key,
  });

  @override
  State<ActionPhaseScreen> createState() => _ActionPhaseScreenState();
}

class _ActionPhaseScreenState extends State<ActionPhaseScreen> {
  final List<String> dummyTasks = const [
    'Swipe card',
    'Fix wiring',
    'Upload data',
    'Align engine',
    'Inspect sample',
  ];

  late final DocumentReference<Map<String, dynamic>> gameRef;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
  }

  Future<void> _callEmergencyMeeting() async {
    // Set meeting phase and called_by player in DB; MeetingScreen will pick this up
    await gameRef.update({
      'phase': 'meeting',
      'meeting_info': {
        'called_by': widget.playerName,
        'type': 'emergency',
        'timestamp': FieldValue.serverTimestamp(),
      },
    });
  }

  void _navigateToMeeting(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingScreen(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportBodyScreen = ReportBodyScreen(roomCode: widget.roomCode, playerName: widget.playerName);
    reportBodyScreen.checkGameEnd(context, widget.roomCode);
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
        title: Text('Action Phase - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final phase = data['phase'] as String? ?? '';
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final currentPlayer = players.firstWhere(
                (p) => p['name'] == widget.playerName,
            orElse: () => {},
          );
          final isDead = currentPlayer['role'] == 'dead';

          // If phase changed to meeting, auto-nav (once)
          if (phase == 'meeting') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _navigateToMeeting(context);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: isDead
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportBodyScreen(
                          roomCode: widget.roomCode,
                          playerName: widget.playerName,
                        ),
                      ),
                    );
                  },
                  child: const Text('Report Dead Body'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isDead ? null : _callEmergencyMeeting,
                  child: const Text('Call Emergency Meeting'),
                ),
                const SizedBox(height: 24),
                const Text('Dummy Task List:', style: TextStyle(fontWeight: FontWeight.bold)),
                ...dummyTasks.map((task) => ListTile(
                  leading: const Icon(Icons.check_box_outline_blank),
                  title: Text(task),
                )),
                if (isDead)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Text(
                      'You are dead. You cannot complete tasks or report/call meetings.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
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