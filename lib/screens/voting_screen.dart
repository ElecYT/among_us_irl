import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meeting_waiting_screen.dart';

class VotingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const VotingScreen({
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    Key? key,
  }) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  String? selectedVote;
  bool _hasVoted = false;
  bool _navigated = false;
  late DocumentReference<Map<String, dynamic>> gameRef;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
  }

  Future<void> _submitVote() async {
    if (selectedVote == null || _hasVoted) return;

    await gameRef.update({
      'votes.${widget.playerName}': selectedVote,
    });

    setState(() => _hasVoted = true);

    // Navigate immediately to MeetingWaitingScreen after vote submission
    _navigateOnce(
      MeetingWaitingScreen(
        roomCode: widget.roomCode,
        playerName: widget.playerName,
        isHost: widget.isHost,
      ),
    );
  }

  void _navigateOnce(Widget screen) {
    if (_navigated || !mounted) return;
    _navigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => screen));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Voting - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() ?? {};
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final votes = Map<String, String>.from(data['votes'] ?? {});
          final phase = data['phase'] ?? '';

          final currentPlayer = players.firstWhere(
                (p) => p['name'] == widget.playerName,
            orElse: () => <String, dynamic>{},
          );
          final isDead = currentPlayer.isNotEmpty && currentPlayer['role'] == 'dead';

          // If phase changed to something other than voting, navigate out here
          // so user is never stuck on outdated screen
          if (phase != 'voting' && !_navigated) {
            Widget targetScreen;

            // For this app's flow, likely only next is MeetingWaitingScreen or beyond
            // But since player navigates to MeetingWaitingScreen immediately on vote,
            // this acts as a safety to catch desyncs if phase changed unexpectedly.
            targetScreen = MeetingWaitingScreen(
              roomCode: widget.roomCode,
              playerName: widget.playerName,
              isHost: widget.isHost,
            );

            _navigateOnce(targetScreen);
            return const SizedBox();
          }

          if (isDead) {
            // Dead players cannot vote: show message
            return Center(
              child: Text(
                'You are dead. You cannot vote.',
                style: const TextStyle(
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }

          final alivePlayers = players.where((p) => p['role'] != 'dead').toList();

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Tap a player to vote:',
                  style: TextStyle(fontSize: 18),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ...alivePlayers.map((p) {
                        final name = p['name'];
                        return RadioListTile<String>(
                          title: Text(name),
                          value: name,
                          groupValue: selectedVote,
                          onChanged: _hasVoted ? null : (val) => setState(() => selectedVote = val),
                        );
                      }),
                      RadioListTile<String>(
                        title: const Text('Skip Vote'),
                        value: 'skip',
                        groupValue: selectedVote,
                        onChanged: _hasVoted ? null : (val) => setState(() => selectedVote = val),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _hasVoted ? null : _submitVote,
                  child: const Text('Submit Vote'),
                ),
                if (_hasVoted)
                  const Padding(
                    padding: EdgeInsets.only(top: 16),
                    child: Text(
                      'Vote submitted. Waiting for others...',
                      style: TextStyle(color: Colors.white70),
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