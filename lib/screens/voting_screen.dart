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

  void _checkIfAllVoted(Map<String, dynamic> data) {
    if (_navigated) return;

    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
    final votes = Map<String, String>.from(data['votes'] ?? {});
    final phase = data['phase'];

    final alivePlayers = players.where((p) => p['role'] != 'dead').length;

    if (phase == 'voting' && votes.length >= alivePlayers) {
      _navigated = true;
      Future.delayed(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        Navigator.pushReplacementNamed(
          context,
          '/ejection',
          arguments: {
            'roomCode': widget.roomCode,
            'playerName': widget.playerName,
          },
        );
      });
    }
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

          // 1. Find current player
          final currentPlayer = players.firstWhere(
                (p) => p['name'] == widget.playerName,
            orElse: () => <String, dynamic>{},
          );
          final isDead = currentPlayer.isNotEmpty && currentPlayer['role'] == 'dead';

          // 2. Always check: If phase is 'ejection', NAVIGATE AWAY (for all players)
          if (phase == 'ejection' && !_navigated) {
            _navigated = true;
            Future.microtask(() {
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

          // 3. Find alive players
          final alivePlayers = players.where((p) => p['role'] != 'dead').toList();

          // 4. If phase is still 'voting', and every alive player has voted, the host should update to 'ejection'
          if (phase == 'voting'
              && votes.keys.toSet().containsAll(alivePlayers.map((p) => p['name']))
              && widget.isHost
          ) {
            // Only the host does this! (If multiple clients, race is ok since it's idempotent.)
            FirebaseFirestore.instance.collection('games').doc(widget.roomCode).update({'phase': 'ejection'});
          }

          // 5. Show proper UI:
          if (isDead) {
            return Center(
              child: Text(
                'You are dead. You cannot vote.',
                style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 20),
                textAlign: TextAlign.center,
              ),
            );
          }

          // 6. Only alive players see voting controls:
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
