import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EjectionScreen extends StatefulWidget {
  final String roomCode;
  final String? playerName; // optional, for navigation

  const EjectionScreen({
    required this.roomCode,
    this.playerName,
    Key? key,
  }) : super(key: key);

  @override
  State<EjectionScreen> createState() => _EjectionScreenState();
}

class _EjectionScreenState extends State<EjectionScreen> {
  bool _isProcessing = false;

  Future<void> _continueToActionPhase(
      Map<String, dynamic> data,
      List<Map<String, dynamic>> players,
      String? ejected,
      bool tie) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    final roomRef =
    FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    try {
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

      if (!mounted) return;

      Navigator.pushReplacementNamed(
        context,
        '/action',
        arguments: {
          'roomCode': widget.roomCode,
          'playerName': widget.playerName,
        },
      );
    } catch (e) {
      print("Error transitioning to action phase: $e");
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance
            .collection('games')
            .doc(widget.roomCode)
            .get(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final votes = Map<String, String>.from(data['votes'] ?? {});
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);

          // Tally votes
          final tally = <String, int>{};
          for (final vote in votes.values) {
            tally[vote] = (tally[vote] ?? 0) + 1;
          }

          // Determine ejection
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

          String message;
          if (tie || ejected == null || ejected == 'skip') {
            message = 'No one was ejected.';
          } else {
            message = '$ejected was ejected.';
          }

          return Padding(
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
                ElevatedButton(
                  onPressed: _isProcessing
                      ? null
                      : () => _continueToActionPhase(data, players, ejected, tie),
                  child: const Text("Continue to Action Phase"),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
