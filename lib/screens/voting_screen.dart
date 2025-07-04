import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class VotingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const VotingScreen({
    required this.roomCode,
    required this.playerName,
    Key? key,
  }) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  String? selectedVote;
  bool _hasVoted = false;

  Future<void> _submitVote() async {
    if (selectedVote == null || _hasVoted) return;

    final gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    await gameRef.update({
      'votes.${widget.playerName}': selectedVote,
    });

    setState(() => _hasVoted = true);
  }

  void _checkIfAllVoted(Map<String, dynamic> data) {
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
    final votes = Map<String, String>.from(data['votes'] ?? {});
    final phase = data['phase'];

    final alivePlayers = players.where((p) => p['role'] != 'dead').length;

    if (phase == 'voting' && votes.length >= alivePlayers) {
      // Delay just a bit to avoid race conditions
      Future.delayed(const Duration(seconds: 1), () {
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

          _checkIfAllVoted(data);

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
                          title: Row(
                            children: [
                              Text(name),
                              if (p['role'] == 'dead') const Icon(Icons.tag, color: Colors.red),
                            ],
                          ),
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
