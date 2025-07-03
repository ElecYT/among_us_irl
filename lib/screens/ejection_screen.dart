import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'action_phase_screen.dart';

class EjectionScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const EjectionScreen({
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    Key? key,
  }) : super(key: key);

  @override
  State<EjectionScreen> createState() => _EjectionScreenState();
}

class _EjectionScreenState extends State<EjectionScreen> {
  bool _isProcessing = false;

  String? ejected;
  bool tie = false;
  List<Map<String, dynamic>> players = [];
  String message = 'Processing...';
  bool _navigated = false;

  Future<void> _processEliminationIfHost() async {
    if (!_isProcessing && widget.isHost) {
      setState(() => _isProcessing = true);

      final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
      try {
        await _loadData();  // Ensure you have latest tally

        // Only host applies elimination and advances phase
        if (!tie && ejected != null && ejected != 'skip') {
          final updatedPlayers = players.map((p) {
            if (p['name'] == ejected) return {...p, 'role': 'dead'};
            return p;
          }).toList();
          await roomRef.update({'players': updatedPlayers});
        }
        await roomRef.update({
          'votes': {},
          'phase': 'action',
        });
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to process elimination: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isProcessing = false);
      }
    }
  }

  Future<void> _loadData() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('games')
        .doc(widget.roomCode)
        .get();

    final data = snapshot.data() as Map<String, dynamic>? ?? {};
    final votes = Map<String, String>.from(data['votes'] ?? {});
    final playerList = List<Map<String, dynamic>>.from(data['players'] ?? []);

    players = playerList;

    // Tally votes
    final tally = <String, int>{};
    for (final vote in votes.values) {
      tally[vote] = (tally[vote] ?? 0) + 1;
    }
    // Determine ejected
    String? result;
    int maxVotes = 0;
    bool isTie = false;
    tally.forEach((key, count) {
      if (count > maxVotes) {
        result = key;
        maxVotes = count;
        isTie = false;
      } else if (count == maxVotes) {
        isTie = true;
      }
    });
    setState(() {
      ejected = result;
      tie = isTie;
      message = (tie || ejected == null || ejected == 'skip')
          ? 'No one was ejected.'
          : '$ejected was ejected.';
    });
  }

  @override
  void initState() {
    super.initState();
    _loadData();
    // Let host auto-advance after a short delay for smoothness (or call from button)
    if (widget.isHost) {
      Future.delayed(const Duration(seconds: 2), _processEliminationIfHost);
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    return StreamBuilder<DocumentSnapshot>(
      stream: roomRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return Scaffold(
            backgroundColor: Colors.black87,
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        final phase = data['phase'] ?? '';

        // Universal phase-driven navigation with duplication guard
        if (phase == 'action' && !_navigated) {
          _navigated = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => ActionPhaseScreen(
                  roomCode: widget.roomCode,
                  playerName: widget.playerName,
                  isHost: widget.isHost,
                ),
              ),
            );
          });
          return const SizedBox();
        }

        return Scaffold(
          backgroundColor: Colors.black87,
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (widget.isHost) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isProcessing ? null : _processEliminationIfHost,
                      child: const Text("Continue to Action Phase"),
                    ),
                  ],
                  if (!widget.isHost) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: null,
                      child: const Text("Waiting for host to continue..."),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}