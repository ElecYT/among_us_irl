import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'action_phase_screen.dart';

class EjectionScreen extends StatefulWidget {
  final String roomCode;
  final String? playerName;
  final bool isHost;

  const EjectionScreen({
    required this.roomCode,
    this.playerName,
    required this.isHost,
    Key? key,
  }) : super(key: key);

  @override
  State<EjectionScreen> createState() => _EjectionScreenState();
}

class _EjectionScreenState extends State<EjectionScreen> {
  bool _hasProcessed = false; // To ensure elimination/phase update runs once

  Future<void> _processEjection(Map<String, dynamic> data) async {
    if (_hasProcessed || !widget.isHost) return;

    final votes = Map<String, String>.from(data['votes'] ?? {});
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

    // Tally votes
    final tally = <String, int>{};
    for (final vote in votes.values) {
      tally[vote] = (tally[vote] ?? 0) + 1;
    }

    String? ejected;
    int maxVotes = 0;
    bool tie = false;
    tally.forEach((key, count) {
      if (count > maxVotes) {
        ejected = key;
        maxVotes = count;
        tie = false;
      } else if (count == maxVotes) {
        tie = true;
      }
    });

    final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    try {
      // Apply elimination only if not tie/skip
      if (!tie && ejected != null && ejected != 'skip') {
        final updatedPlayers = players.map((p) {
          if (p['name'] == ejected) return {...p, 'role': 'dead'};
          return p;
        }).toList();

        await roomRef.update({'players': updatedPlayers});
      }
      await Future.delayed(const Duration(seconds: 3));
      // then update Firestore phase to 'action'
      // Advance phase to 'action' after applying elimination
      if (data['phase'] == 'ejection' && widget.isHost) {
        await roomRef.update({'votes': {}, 'phase': 'action'});
      }
      _hasProcessed = true;
    } catch (e) {
      print("Error processing ejection: $e");
      // Optionally show error in UI here
    }
  }

  @override
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    return Scaffold(
      backgroundColor: Colors.black87,
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: roomRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final phase = data['phase'] ?? '';
          final votes = Map<String, String>.from(data['votes'] ?? {});
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

          // React to phase changes
          if (phase == 'action') {
            // Navigate to action phase screen automatically
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => ActionPhaseScreen(
                    roomCode: widget.roomCode,
                    playerName: widget.playerName ?? '',
                    isHost: widget.isHost,
                  ),
                ),
              );
            });
            return const SizedBox();
          }

          if (phase == 'ejection') {
            // Process elimination + phase advance automatically (only host)
            _processEjection(data);

            // Tally votes for message
            final tally = <String, int>{};
            for (final vote in votes.values) {
              tally[vote] = (tally[vote] ?? 0) + 1;
            }
            String? ejected;
            int maxVotes = 0;
            bool tie = false;
            tally.forEach((key, count) {
              if (count > maxVotes) {
                ejected = key;
                maxVotes = count;
                tie = false;
              } else if (count == maxVotes) {
                tie = true;
              }
            });

            final message = (tie || ejected == null || ejected == 'skip')
                ? 'No one was ejected.'
                : '$ejected was ejected.';

            return Center(
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
                    const SizedBox(height: 24),
                    if (widget.isHost)
                      const Text(
                        'Waiting for phase to advance to Action...',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      )
                    else
                      const Text(
                        'Waiting for host to advance phase...',
                        style: TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                  ],
                ),
              ),
            );
          }

          // Default fallback in case player somehow ends up here
          return const Center(
            child: Text(
              'Waiting for ejection phase to start...',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }
}