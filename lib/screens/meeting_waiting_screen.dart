import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'ejection_screen.dart';
import 'voting_screen.dart'; // Not used in this file

class MeetingWaitingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;

  const MeetingWaitingScreen({required this.roomCode, required this.playerName, Key? key}) : super(key: key);

  @override
  State<MeetingWaitingScreen> createState() => _MeetingWaitingScreenState();
}

class _MeetingWaitingScreenState extends State<MeetingWaitingScreen> {
  late final DocumentReference<Map<String, dynamic>> gameRef;
  Timer? countdownTimer;
  int secondsLeft = 60; // Default value, will be updated
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    // _startCountdownListener will set up the timer based on 'voting_deadline'
    _startCountdownListener();
    // _listenForGamePhaseChanges will react if Firestore 'phase' changes to 'ejection' or 'results'
    _listenForGamePhaseChanges();
  }

  void _startCountdownListener() async {
    try {
      final snapshot = await gameRef.get();
      final data = snapshot.data();
      // Ensure data is not null and 'voting_deadline' exists and is a String
      if (data != null && data.containsKey('voting_deadline') && data['voting_deadline'] is String) {
        final deadlineString = data['voting_deadline'] as String;
        final deadline = DateTime.tryParse(deadlineString);

        if (deadline != null) {
          // Calculate initial secondsLeft accurately
          final now = DateTime.now();
          final initialDiff = deadline.difference(now).inSeconds;
          if (mounted) {
            setState(() {
              secondsLeft = initialDiff > 0 ? initialDiff : 0;
            });
          }

          if (initialDiff <= 0) {
            // If deadline already passed, potentially navigate or handle
            if (secondsLeft == 0 && mounted && !_hasNavigated) {
              // Consider if immediate navigation is needed or if phase change handles it
              // For now, _navigateToEjectionScreen in build method will handle it
            }
            return; // No need to start timer if deadline passed
          }

          countdownTimer?.cancel(); // Cancel any existing timer
          countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            if (!mounted) {
              timer.cancel();
              return;
            }
            final now = DateTime.now();
            final diff = deadline.difference(now).inSeconds;
            if (diff <= 0) {
              timer.cancel();
              if (mounted) setState(() => secondsLeft = 0);
              // Navigation will be handled by the build method reacting to secondsLeft or phase change
            } else {
              if (mounted) setState(() => secondsLeft = diff);
            }
          });
        } else {
          if (mounted) setState(() => secondsLeft = 60); // Fallback if deadline parsing fails
        }
      } else {
        // voting_deadline not available or not a string, start a default timer or wait
        // This screen's purpose is "MeetingWaiting" which implies it's waiting for voting to END.
        // So, if no deadline, it should probably show a generic waiting message.
        // Or, it should react to the game 'phase' to know if it should even be showing a countdown.
        print("Warning: 'voting_deadline' not found or not a String. Defaulting countdown or waiting for phase.");
        // Consider removing the default 60s countdown if this screen strictly depends on a Firestore deadline
        if (mounted) setState(() => secondsLeft = 60); // Fallback
      }
    } catch (e) {
      print("Error in _startCountdownListener: $e");
      if (mounted) setState(() => secondsLeft = 60); // Fallback on any error
    }
  }

  // Added: Listener for game phase changes
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _gamePhaseSubscription;

  void _listenForGamePhaseChanges() {
    _gamePhaseSubscription = gameRef.snapshots().listen((snapshot) {
      if (!mounted || _hasNavigated) return;
      final data = snapshot.data();
      if (data == null) return;

      final phase = data['phase'] as String?;
      print("MeetingWaitingScreen: Phase changed to $phase");

      // This is a key part: if an external process (like a Cloud Function after deadline)
      // changes the phase, this screen will navigate.
      if (phase == 'ejection' || phase == 'results') {
        _navigateOnce(EjectionScreen(roomCode: widget.roomCode, playerName: widget.playerName));
      }

      // If voting_deadline is updated dynamically (e.g. admin extends time), re-init countdown
      if (data.containsKey('voting_deadline') && data['voting_deadline'] is String) {
        // Potentially add a check here to see if the new deadline string is actually different
        // from the one currently used by the timer to avoid unnecessary restarts.
        _startCountdownListener();
      }
    }, onError: (error) {
      print("Error listening to game phase changes: $error");
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    _gamePhaseSubscription?.cancel();
    super.dispose();
  }

  void _navigateOnce(Widget targetScreen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    // Use addPostFrameCallback to ensure navigation happens after the build phase
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) { // Re-check mounted status as callback is asynchronous
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => targetScreen),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // This screen should primarily use its own state (secondsLeft derived from voting_deadline)
    // and the phase listener (_listenForGamePhaseChanges) to determine navigation.
    // Reading Firestore directly in the StreamBuilder for 'report' data is fine for display.

    return MaterialApp(
        theme: ThemeData(
        primarySwatch: Colors.grey, // Dark theme base color
        brightness: Brightness.dark, // Setting the brightness to dark
        scaffoldBackgroundColor: Colors.black87, // Dark background color for the whole app
        cardColor: Colors.blueGrey[900], // Color of cards like dialogs or bottom sheets
        textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white), // Text color in light mode
    bodySmall: TextStyle(color: Colors.white70),
    bodyMedium: TextStyle(color: Colors.white70),
    titleLarge: TextStyle(color: Colors.white70),
    titleMedium: TextStyle(color: Colors.white70),
    titleSmall: TextStyle(color: Colors.white70),
    ),
    ),
    home: Scaffold(
      appBar: AppBar(
        title: Text('Meeting Results Pending - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          // This StreamBuilder is mainly for displaying dynamic data like 'report' details.
          // The core navigation logic based on the timer or phase change is handled
          // outside or in conjunction with 'secondsLeft' and '_hasNavigated'.
          child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: gameRef.snapshots(),
            builder: (context, snapshot) {
              // ----- UI State 1: Still counting down (and StreamBuilder might be initially waiting) -----
              if (snapshot.connectionState == ConnectionState.waiting && secondsLeft > 0) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('Voting phase ends in $secondsLeft seconds...', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(),
                    const SizedBox(height: 20),
                    const Text('Waiting for voting to conclude...', style: TextStyle(fontSize: 18)),
                  ],
                );
              }

              if (snapshot.hasError) {
                return Text("Error loading game data: ${snapshot.error}");
              }

              // Extract report data for display (this is fine)
              final gameData = snapshot.data?.data();
              final reportData = gameData?['report'] as Map<String, dynamic>? ?? {};
              final reporter = reportData['reporter'] as String? ?? "Unknown";
              final victim = reportData['victim'] as String? ?? "Unknown";
              final location = reportData['location'] as String? ?? "Unknown";

              // ----- Navigation Logic: Triggered by this screen's timer expiring -----
              // This is one of the ways to navigate.
              // If this screen's local countdown reaches 0, it means the deadline *according to this client* has passed.
              if (secondsLeft <= 0 && !_hasNavigated) {
                // _navigateOnce handles the actual Navigator.pushReplacement
                // and ensures it only happens once.
                _navigateOnce(EjectionScreen(roomCode: widget.roomCode, playerName: widget.playerName));

                // While navigation is pending (it happens in a post-frame callback),
                // show a loading message. The build method MUST return a widget.
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Text("Voting ended. Preparing results...", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 20),
                    CircularProgressIndicator(),
                  ],
                );
              }

              // ----- UI State 2: Countdown is active, or timer has ended but waiting for phase change -----
              // This UI is shown if secondsLeft > 0, OR if secondsLeft <= 0 but _hasNavigated is true
              // (meaning navigation is already in progress due to the block above or phase change listener).
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (secondsLeft > 0) // Only show countdown if time is remaining
                    Text('Voting phase ends in $secondsLeft seconds...', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  if (secondsLeft > 0)
                    const Text('Waiting for other players to finish voting...', style: TextStyle(fontSize: 18)),
                  const SizedBox(height: 30),

                  // Display report details if available
                  if (gameData != null && reportData.isNotEmpty) ...[
                    Card(
                      elevation: 3,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("Report Details:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text('Reported by: $reporter'),
                            Text('Body found: $victim'),
                            Text('Location: $location'),
                          ],
                        ),
                      ),
                    ),
                  ] else if (snapshot.connectionState != ConnectionState.waiting)
                  // If no report details and not initially loading, show this message.
                    const Text("No report details available or loading...", style: TextStyle(fontSize: 16)),

                  const SizedBox(height: 20),
                  if (secondsLeft > 0) // Show indicator only if still counting down
                    const CircularProgressIndicator(),
                ],
              );
            },
          ),
        ),
      ),
    ),
    );
  }

// This method was problematic:
// 1. It was called directly in the build method where a Widget was expected.
// 2. It returned a GestureDetector, but the navigation was more of a side effect.
// It's better to handle navigation directly in the build logic or via _navigateOnce.
/*
  Widget _navigateToEjectionScreen() {
    // This should not be a widget that triggers navigation on tap here.
    // Navigation should be triggered by timer end or phase change.
    _navigateOnce(EjectionScreen(roomCode: widget.roomCode, playerName: widget.playerName));
    return const Text("Voting ended. Navigating to Ejection...", style: TextStyle(fontSize: 18));
  }
  */
}