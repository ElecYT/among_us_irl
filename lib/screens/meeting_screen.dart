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
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    // Host sets meeting start time / voting deadline once:
    if (widget.isHost) {
      _setMeetingStartTimestampAndDeadline();
    }
  }

  Future<void> _setMeetingStartTimestampAndDeadline() async {
    final now = DateTime.now().toUtc();
    final votingDeadline = now.add(const Duration(seconds: 15 + 60)); // 15s meeting + 60s voting
    await gameRef.update({
      'phase': 'meeting',
      'meeting_start_timestamp': now.toIso8601String(),
      'voting_deadline': votingDeadline.toIso8601String(),
    });
  }

  void _navigateOnce(BuildContext context, Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    });
  }

  int _calculateSecondsRemaining(String meetingStartIso, String votingDeadlineIso) {
    final meetingStart = DateTime.tryParse(meetingStartIso)?.toUtc();
    final votingDeadline = DateTime.tryParse(votingDeadlineIso)?.toUtc();
    if (meetingStart == null || votingDeadline == null) return 0;

    final now = DateTime.now().toUtc();
    final meetingDuration = votingDeadline.difference(meetingStart) - const Duration(seconds: 60);
    final meetingEnd = meetingStart.add(meetingDuration);

    final secondsLeft = meetingEnd.difference(now).inSeconds;
    return secondsLeft > 0 ? secondsLeft : 0;
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

          final meetingStartIso = data['meeting_start_timestamp'] as String? ?? '';
          final votingDeadlineIso = data['voting_deadline'] as String? ?? '';

          if (!_navigated) {
            if (phase == 'voting') {
              if (votingDeadlineIso.isNotEmpty) {
                final votingDeadline = DateTime.tryParse(votingDeadlineIso);
                if (votingDeadline != null && DateTime.now().toUtc().isAfter(votingDeadline)) {
                  _navigateOnce(
                      context,
                      EjectionScreen(
                        roomCode: widget.roomCode,
                        playerName: widget.playerName,
                        isHost: widget.isHost,
                      ));
                  return const Center(child: Text('Voting ended. Navigating to Ejection...'));
                } else {
                  _navigateOnce(
                      context,
                      VotingScreen(
                        roomCode: widget.roomCode,
                        playerName: widget.playerName,
                        isHost: widget.isHost,
                      ));
                  return const Center(child: Text('Navigating to Voting Screen...'));
                }
              } else {
                return const Center(child: Text('Waiting for voting deadline...'));
              }
            }
          }

          // Calculate remaining meeting seconds based on timestamps
          final secondsRemaining = _calculateSecondsRemaining(meetingStartIso, votingDeadlineIso);

          // Default Meeting UI
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