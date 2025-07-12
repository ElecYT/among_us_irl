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
  bool _hasProcessed = false;

  Future<void> _processEjection(Map<String, dynamic> data) async {
    if (_hasProcessed || !widget.isHost) return;

    final votes = Map<String, String>.from(data['votes'] ?? {});
    final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

    // Tally votes (ignoring 'skip')
    final tally = <String, int>{};
    for (final vote in votes.values) {
      tally[vote] = (tally[vote] ?? 0) + 1;
    }

    String? ejected;
    int maxVotes = 0;
    bool tie = false;
    tally.forEach((key, count) {
      if (key == 'skip') return; // Ignore skip votes for determining ejection
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
      if (!tie && ejected != null) {
        final updatedPlayers = players.map((p) {
          if (p['name'] == ejected) return {...p, 'role': 'dead'};
          return p;
        }).toList();
        await roomRef.update({'players': updatedPlayers});
      }

      await Future.delayed(const Duration(seconds: 3));

      if (data['phase'] == 'ejection') {
        await roomRef.update({'votes': {}, 'phase': 'action'});
      }

      _hasProcessed = true;
    } catch (e) {
      print("Error processing ejection: $e");
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

          if (phase == 'action') {
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

          if (phase == 'ejection') {
            _processEjection(data);

            // Tally for UI (skip included for message logic)
            final tally = <String, int>{};
            for (final vote in votes.values) {
              tally[vote] = (tally[vote] ?? 0) + 1;
            }

            String? ejected;
            int maxVotes = 0;
            bool tie = false;
            tally.forEach((key, count) {
              if (key == 'skip') return;
              if (count > maxVotes) {
                ejected = key;
                maxVotes = count;
                tie = false;
              } else if (count == maxVotes) {
                tie = true;
              }
            });

            final message = (tie || ejected == null)
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
                    Text(
                      widget.isHost
                          ? 'Waiting for phase to advance to Action...'
                          : 'Waiting for host to advance phase...',
                      style: const TextStyle(color: Colors.white70),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

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
