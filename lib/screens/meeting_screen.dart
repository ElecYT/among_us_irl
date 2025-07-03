import 'dart:async';

import 'package:among_us_irl/screens/report_body_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'voting_screen.dart';
import 'ejection_screen.dart';

class MeetingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const MeetingScreen({
    required this.roomCode,
    required this.playerName,
    super.key,
  });

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late final DocumentReference gameRef;
  int secondsRemaining = 15;
  Timer? timer;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    startDiscussionTimer();
  }

  void startDiscussionTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (secondsRemaining <= 1) {
        t.cancel();
        // Set voting phase and a deadline, one time
        await gameRef.update({
          'phase': 'voting',
          'voting_deadline': DateTime.now().add(const Duration(seconds: 60)).toIso8601String(),
        });
      } else {
        setState(() => secondsRemaining--);
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  void _navigateOnce(BuildContext context, Widget screen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => screen),
      );
    });
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
        title: Text('Meeting - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final report = data['report'] as Map<String, dynamic>? ?? {};
          final reportedBy = report['reporter']?.toString() ?? 'Unknown';
          final deadPlayer = report['victim']?.toString() ?? 'Unknown';
          final location = report['location']?.toString() ?? 'Unknown';
          final phase = data['phase'] ?? 'waiting';

          // Phase navigation
          if (phase == 'voting') {
            final dynamic deadlineData = data['voting_deadline'];
            if (deadlineData is String) {
              final deadline = DateTime.tryParse(deadlineData);
              final now = DateTime.now();
              if (deadline != null && now.isAfter(deadline)) {
                // Voting deadline over, go to ejection
                _navigateOnce(context, EjectionScreen(roomCode: widget.roomCode, playerName: widget.playerName));
                return const Center(child: Text('Voting ended. Navigating to Ejection...'));
              } else {
                _navigateOnce(context, VotingScreen(roomCode: widget.roomCode, playerName: widget.playerName));
                return const Center(child: Text('Navigating to Voting Screen...'));
              }
            } else {
              // Waiting for voting_deadline field to appear
              return const Center(child: Text('Waiting for voting deadline to be set...'));
            }
          }

          // Default: show the meeting (discussion) UI
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Return at once to the Dining Room to discuss.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text('Body reported by: $reportedBy'),
                Text('Dead Person: $deadPlayer'),
                Text('Location: $location'),
                const SizedBox(height: 16),
                const Text('Players:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...players.map((player) {
                  final name = player['name'];
                  final isDead = player['role'] == 'dead';
                  return ListTile(
                    leading: Icon(isDead ? Icons.sell : Icons.person),
                    title: Text(
                      isDead ? '☠️ $name' : name,
                      style: TextStyle(
                        color: isDead ? Colors.grey : Colors.white,
                        decoration: isDead ? TextDecoration.lineThrough : null,
                      ),
                    ),
                  );
                }),
                const Spacer(),
                Center(
                  child: Text(
                    'Discussion Time Remaining: $secondsRemaining seconds',
                    style: const TextStyle(fontSize: 16),
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