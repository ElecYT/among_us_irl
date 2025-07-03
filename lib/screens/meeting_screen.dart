import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'voting_screen.dart';
import 'ejection_screen.dart';

class MeetingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const MeetingScreen({
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    Key? key,
  }) : super(key: key);

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  late final DocumentReference<Map<String, dynamic>> gameRef;
  int secondsRemaining = 15;
  Timer? timer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    if (widget.isHost) {
      startDiscussionTimer();
    }
  }

  void startDiscussionTimer() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (secondsRemaining <= 1) {
        t.cancel();
        // Only host sets voting phase/timer
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
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Meeting - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() ?? {};
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final report = data['report'] as Map<String, dynamic>? ?? {};
          final reportedBy = report['reporter']?.toString() ?? 'Unknown';
          final deadPlayer = report['victim']?.toString() ?? 'Unknown';
          final location = report['location']?.toString() ?? 'Unknown';
          final phase = data['phase'] ?? 'waiting';

          // 🚦 PHASE-DRIVEN NAVIGATION
          if (!_navigated) {
            if (phase == 'voting') {
              final dynamic deadlineData = data['voting_deadline'];
              if (deadlineData is String) {
                final deadline = DateTime.tryParse(deadlineData);
                final now = DateTime.now();
                if (deadline != null && now.isAfter(deadline)) {
                  // Voting time over, go to ejection
                  _navigateOnce(context, EjectionScreen(
                      roomCode: widget.roomCode,
                      playerName: widget.playerName,
                      isHost: widget.isHost));
                  return const Center(child: Text('Voting ended. Navigating to Ejection...'));
                } else {
                  _navigateOnce(context, VotingScreen(
                      roomCode: widget.roomCode,
                      playerName: widget.playerName,
                      isHost: widget.isHost));
                  return const Center(child: Text('Navigating to Voting Screen...'));
                }
              } else {
                return const Center(child: Text('Waiting for voting deadline...'));
              }
            }
            // If you ever support emergency skip: add more phase checks here!
          }

          // Default: Show the discussion screen
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
    );
  }
}