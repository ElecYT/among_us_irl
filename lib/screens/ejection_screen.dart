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
  bool _hasNavigated = false;

    Future<void> _processEjection(Map<String, dynamic> _) async {
      if (_hasProcessed || !widget.isHost) return;
    
      final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

      try {
        await roomRef.runTransaction((txn) async {
          final snap = await txn.get(roomRef);
          final data = snap.data() as Map<String, dynamic>? ?? {};

          // Only process once, only during ejection
          if (data['phase'] != 'ejection') return;

          final votes = Map<String, String>.from(data['votes'] ?? {});
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

          // Count only alive players for safety
          final alive = players.where((p) => p['role'] != 'dead').map((p) => p['name'] as String).toSet();

          // Build counts (including skip as a "candidate")
          final counts = <String, int>{};
          votes.forEach((voter, choice) {
            if (!alive.contains(voter)) return; // dead voters ignored
            counts[choice] = (counts[choice] ?? 0) + 1;
          });

          final skipCount = counts['skip'] ?? 0;

          // Find top-voted player (excluding skip)
          String? topPlayer;
          int topVotes = 0;
          bool tie = false;

          counts.forEach((choice, c) {
            if (choice == 'skip') return;
            if (c > topVotes) {
              topVotes = c;
              topPlayer = choice;
              tie = false;
            } else if (c == topVotes && c != 0) {
              tie = true;
            }
          });

          // Among Us rule:
          // - if tie OR no votes OR skip >= topVotes => no ejection
          final shouldEject = !tie && topPlayer != null && topVotes > 0 && skipCount < topVotes;

          if (shouldEject) {
            final updatedPlayers = players.map((p) {
              if (p['name'] == topPlayer) return {...p, 'role': 'dead'};
              return p;
            }).toList();
            txn.update(roomRef, {'players': updatedPlayers});
          }

          // Clear votes and advance
          txn.update(roomRef, {'votes': {}, 'phase': 'action'});
        });

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

          if (phase == 'action' && !_hasNavigated) {
            _hasNavigated = true;
            Future.microtask(() {
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
