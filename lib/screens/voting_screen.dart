import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ejection_screen.dart';

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

  Future<void> _submitVote() async {
    if (selectedVote == null || _hasVoted) return;

    final gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    await gameRef.update({
      'votes.${widget.playerName}': selectedVote,
    });

    setState(() => _hasVoted = true);
  }

  @override
  Widget build(BuildContext context) {
    final gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    return Scaffold(
      appBar: AppBar(
        title: Text('Voting - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final votes = Map<String, String>.from(data['votes'] ?? {});
          final phase = data['phase'];

          // Find current player info
          final currentPlayer = players.firstWhere(
                (p) => p['name'] == widget.playerName,
            orElse: () => <String, dynamic>{},
          );
          final isDead = currentPlayer.isNotEmpty && currentPlayer['role'] == 'dead';

          // Phase-driven navigation to EjectionScreen when phase changes
          if (phase == 'ejection' && !_navigated) {
            _navigated = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => EjectionScreen(
                    roomCode: widget.roomCode,
                    playerName: widget.playerName,
                    isHost: widget.isHost,
                  ),
                ),
              );
            });
            return const SizedBox();
          }

          // Only show alive players for voting
          final alivePlayers = players.where((p) => p['role'] != 'dead').toList();

          // Host updates phase to 'ejection' when all alive players have voted
          if (phase == 'voting' &&
              votes.keys.toSet().containsAll(alivePlayers.map((p) => p['name'])) &&
              widget.isHost) {
            // Firestore update; idempotent so safe even if triggered multiple times
            gameRef.update({'phase': 'ejection'});
          }

          if (isDead) {
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
                const SizedBox(height: 16),
                if (_hasVoted)
                  const Text(
                    'Vote submitted. Waiting for others...',
                    style: TextStyle(color: Colors.white70),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}