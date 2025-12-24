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

    final roomRef =
    FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    try {
      await FirebaseFirestore.instance.runTransaction((txn) async {
        final snap = await txn.get(roomRef);
        final data = snap.data() as Map<String, dynamic>? ?? {};

        // Only process once, only during the ejection phase
        if (data['phase'] != 'ejection') return;

        // votes: expected shape { "voterName": "targetName" } where targetName may be "skip"
        final rawVotes = data['votes'];
        final Map<String, String> votes = {};
        if (rawVotes is Map) {
          for (final entry in rawVotes.entries) {
            final k = entry.key?.toString();
            final v = entry.value?.toString();
            if (k != null && v != null) votes[k] = v;
          }
        }

        // players: expected list of maps with at least { "name": ..., "role": ... }
        final rawPlayers = data['players'];
        final List<Map<String, dynamic>> players = (rawPlayers is List)
            ? rawPlayers
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList()
            : <Map<String, dynamic>>[];

        // Only alive players should count as voters (and valid targets)
        bool isAlivePlayer(String name) {
          for (final p in players) {
            if (p['name']?.toString() == name) {
              return p['role']?.toString() != 'dead';
            }
          }
          return false;
        }

        // Count votes (including skip as its own bucket)
        final Map<String, int> counts = {};
        votes.forEach((voter, choice) {
          if (!isAlivePlayer(voter)) return;
          counts[choice] = (counts[choice] ?? 0) + 1;
        });

        final int skipCount = counts['skip'] ?? 0;

        // Find top-voted player excluding skip; detect ties
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

        // Among Us-style rule:
        // - tie => no ejection
        // - skip >= topVotes => no ejection
        // - no votes => no ejection
        final bool shouldEject =
            !tie && topPlayer != null && topVotes > 0 && skipCount < topVotes;

        if (shouldEject) {
          final updatedPlayers = players.map((p) {
            if (p['name']?.toString() == topPlayer) {
              return <String, dynamic>{...p, 'role': 'dead'};
            }
            return p;
          }).toList();

          txn.update(roomRef, {'players': updatedPlayers});
        }

        // Clear votes and advance phase (adjust 'action' if your next phase differs)
        txn.update(roomRef, {'votes': {}, 'phase': 'action'});
      });

      _hasProcessed = true;
    } catch (e) {
      // Keep it simple; you can swap to your logger if you have one.
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
