import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  Timer? countdownTimer;
  int countdown = 15; // meeting time seconds

  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    if (widget.isHost) {
      startCountdown();
    }
  }

  void startCountdown() {
    countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      if (countdown <= 1) {
        timer.cancel();
        // Host updates Firestore phase and voting deadline
        final deadline = DateTime.now().toUtc().add(const Duration(seconds: 60));
        await gameRef.update({
          'phase': 'voting',
          'voting_deadline': deadline.toIso8601String(),
        });
      } else {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          countdown--;
        });
      }
    });
  }

  void _navigateOnce(BuildContext context, Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
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
          final phase = data['phase'] ?? 'waiting';

          if (phase == 'voting' && !_navigated) {
            final votingDeadlineStr = data['voting_deadline'] as String?;
            if (votingDeadlineStr == null) {
              return const Center(child: Text('Waiting for voting deadline...'));
            }
            final votingDeadline = DateTime.tryParse(votingDeadlineStr)?.toUtc();
            if (votingDeadline == null) {
              return const Center(child: Text('Waiting for voting deadline...'));
            }

            if (DateTime.now().toUtc().isAfter(votingDeadline)) {
              _navigateOnce(
                context,
                EjectionScreen(
                  roomCode: widget.roomCode,
                  playerName: widget.playerName,
                  isHost: widget.isHost,
                ),
              );
              return const Center(child: Text('Voting ended. Navigating to Ejection...'));
            } else {
              _navigateOnce(
                context,
                VotingScreen(
                  roomCode: widget.roomCode,
                  playerName: widget.playerName,
                  isHost: widget.isHost,
                ),
              );
              return const Center(child: Text('Navigating to Voting Screen...'));
            }
          }

          // Display meeting UI w/ local countdown
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final report = data['report'] as Map<String, dynamic>? ?? {};
          final reportedBy = report['reporter']?.toString() ?? 'Unknown';
          final deadPlayer = report['victim']?.toString() ?? 'Unknown';
          final location = report['location']?.toString() ?? 'Unknown';

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
                    'Discussion Time Remaining: $countdown seconds',
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