import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class EjectionScreen extends StatefulWidget {
  final String roomCode;
  final String? playerName; // keep for navigation if passed

  const EjectionScreen({required this.roomCode, this.playerName, Key? key}) : super(key: key);

  @override
  State<EjectionScreen> createState() => _EjectionScreenState();
}

class _EjectionScreenState extends State<EjectionScreen> {
  bool _navigated = false; // To prevent double navigation

  @override
  Widget build(BuildContext context) {
    // DO NOT return a MaterialApp here.
    // The EjectionScreen is part of a larger application
    // that already has a MaterialApp at its root.

    // The theme should be inherited from the root MaterialApp,
    // or you can apply specific theme overrides to widgets if needed,
    // but not by wrapping individual screens in their own MaterialApp.

    return Scaffold( // Return a Scaffold directly
      // You can set scaffoldBackgroundColor here if you want it different from the global theme
      // backgroundColor: Colors.black87,
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('games').doc(widget.roomCode).get(),
        builder: (context, snapshot) { // This 'context' now comes from the main MaterialApp's Navigator
          if (snapshot.connectionState == ConnectionState.waiting || !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final votes = Map<String, String>.from(data['votes'] ?? {});
          // It's safer to get players from the snapshot AFTER checking hasData
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);


          // ----- Tally the votes -----
          final tally = <String, int>{};
          for (final vote in votes.values) {
            tally[vote] = (tally[vote] ?? 0) + 1;
          }

          // ----- Find who gets ejected -----
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

          // After delay, go to action phase (only once)
          // Make sure this Future.delayed is only called once.
          // Placing it here means it runs every time the FutureBuilder rebuilds with data.
          // Consider moving this logic to initState or using a flag to ensure it's
          // scheduled only once after the initial data load.
          // For now, _navigated helps, but if FutureBuilder refetches, it might reschedule.
          // A simple way to ensure it runs once per screen lifetime after data is loaded:
          // Use WidgetsBinding.instance.addPostFrameCallback if this logic
          // should run after the first frame that displays the message.
          // Or, manage a state variable like _isTimerScheduled.

          // For simplicity, let's assume _navigated is sufficient for now,
          // but be mindful if the FutureBuilder re-runs unexpectedly.

          if (!_navigated) { // Schedule the delayed task only if not already navigated/scheduled
            Future.delayed(const Duration(seconds: 5), () async {
              if (!mounted || _navigated) { // Re-check _navigated inside the delayed callback
                print("EjectionScreen: Navigation aborted (mounted: $mounted, _navigated: $_navigated)");
                return;
              }
              // Set _navigated to true HERE, right before starting actions that lead to navigation
              _navigated = true;
              print("EjectionScreen: Timer fired. Attempting to transition to action phase for room ${widget.roomCode}");


              final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
              bool successfullyUpdatedPhase = false;

              try {
                if (!tie && ejected != null && ejected != 'skip') {
                  print("EjectionScreen: Marking '$ejected' as dead.");
                  final updatedPlayersList = players.map((p) { // Use 'players' from FutureBuilder
                    if (p['name'] == ejected) return {...p, 'role': 'dead'};
                    return p;
                  }).toList();

                  if (!mounted) return;
                  await roomRef.update({'players': updatedPlayersList});
                  print("EjectionScreen: Player '$ejected' marked as dead in Firestore.");
                }

                if (!mounted) return;
                print("EjectionScreen: Updating phase to 'action' and clearing votes.");
                await roomRef.update({
                  'votes': {},
                  'phase': 'action',
                });
                successfullyUpdatedPhase = true;
                print("EjectionScreen: Phase updated to 'action' in Firestore.");

              } catch (e) {
                print("EjectionScreen: Firestore update error during transition: $e");
                // IMPORTANT: If an error occurs, reset _navigated so that if the screen
                // somehow stays or this logic is re-triggered, it can try again.
                // Or handle error more gracefully (e.g. show message).
                if (mounted) {
                  setState(() { _navigated = false; }); // Allow retry by some means
                }
                return;
              }

              if (!mounted) return;

              if (successfullyUpdatedPhase) {
                print("EjectionScreen: Navigating to /action screen.");
                // This context is now the correct one from the root MaterialApp
                Navigator.pushReplacementNamed(
                  context,
                  '/action',
                  arguments: {
                    'roomCode': widget.roomCode,
                    'playerName': widget.playerName,
                  },
                );
              } else {
                print("EjectionScreen: Did not navigate because phase update was not successful.");
                if (mounted) {
                  setState(() { _navigated = false; }); // Reset to allow potential retry
                }
              }
            });
          }

          // This is the UI that will be shown by the Scaffold returned by the EjectionScreen's build method
          return Center(
            child: Text(
              message,
              // Apply text styles directly or ensure they are inherited from the main theme
              style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.white),
              textAlign: TextAlign.center,
            ),
          );
        },
      ),
    );
  }
}