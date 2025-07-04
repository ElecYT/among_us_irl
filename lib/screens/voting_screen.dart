import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'ejection_screen.dart';
import 'meeting_waiting_screen.dart';

class VotingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const VotingScreen({required this.roomCode, required this.playerName, required this.isHost, Key? key}) : super(key: key);

  @override
  State<VotingScreen> createState() => _VotingScreenState();
}

class _VotingScreenState extends State<VotingScreen> {
  String? selectedVote;
  Timer? countdownTimer;
  int secondsLeft = 60;
  late DocumentReference<Map<String, dynamic>> gameRef;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    gameRef =
        FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    _startCountdownListener();
  }

  void _startCountdownListener() async {
    try {
      final snapshot = await gameRef.get();
      final data = snapshot.data();
      final deadlineString = data?['voting_deadline'] as String?;

      if (deadlineString != null) {
        final deadline = DateTime.tryParse(deadlineString);
        if (deadline != null) {
          countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
            final now = DateTime.now();
            final diff = deadline
                .difference(now)
                .inSeconds;
            if (diff <= 0) {
              timer.cancel();
              if (mounted) setState(() => secondsLeft = 0);
            } else {
              if (mounted) setState(() => secondsLeft = diff);
            }
          });
        }
      }
    } catch (_) {
      if (mounted) setState(() => secondsLeft = 60);
    }
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  void _navigateOnce(Widget screen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => screen));
    });
  }


  @override
  Widget build(BuildContext context) {
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
    home: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: gameRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() ?? {};
        final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
        final votes = Map<String, String>.from(
            data['votes'] ?? {}); // Used to check if current player has voted
        final phase = data['phase']?.toString() ??
            'voting'; // Current game phase

        final currentPlayer = players.firstWhere(
              (p) => p['name'] == widget.playerName,
          orElse: () => {'role': 'unknown'}, // Default to unknown if not found
        );
        final bool isDead = currentPlayer['role'] == 'dead';

        final alivePlayers =
        players.where((p) => p['role'] != 'dead').map<String>((
            p) => p['name'] as String).toList();
        final bool hasVoted = votes.containsKey(widget.playerName);

        // --- Common Navigation Logic for Deadline and Phase Changes ---
        final votingDeadlineStr = data['voting_deadline'] as String?;
        final votingDeadline = votingDeadlineStr != null ? DateTime.tryParse(
            votingDeadlineStr) : null;
        final now = DateTime.now();
        bool deadlineHasPassed = votingDeadline != null &&
            now.isAfter(votingDeadline);

        // 1. If phase changes to 'action', everyone (alive or dead) should go to the action phase screen.
        //    The ActionRedirect widget handles the actual navigation to '/action'.
        if (phase == 'action') {
          _navigateOnce(ActionRedirect(
            roomCode: widget.roomCode,
            playerName: widget.playerName,
          ));
          return const Scaffold(body: Center(child: CircularProgressIndicator(
              key: Key("loading_action")))); // Placeholder
        }

        // 2. If phase changes to 'ejection' (or results), everyone should typically see who was ejected.
        //    Alive players who just voted will go here. Dead players also observe.
        if (phase == 'ejection' || phase ==
            'results') { // Assuming 'results' is another valid phase post-voting
          _navigateOnce(EjectionScreen(
              roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost));
          return const Scaffold(body: Center(child: CircularProgressIndicator(
              key: Key("loading_ejection_phase"))));
        }

        // --- Logic Specific to Dead Players ---
        if (isDead) {
          // If the player is dead:
          // They should stay on a "You are dead" message screen during the voting phase.
          // Once the voting deadline passes OR the phase moves beyond 'voting' (handled above),
          // they should be navigated away.

          if (deadlineHasPassed && phase == 'voting') {
            // If the deadline passes and we are still in the 'voting' phase (meaning the backend/Cloud Function
            // hasn't updated the phase to 'ejection' or 'action' yet),
            // dead players should eventually move to the action phase.
            // However, it's generally better to wait for the phase to officially change.
            // For now, let's assume the phase WILL change. If it doesn't, this screen will be stuck.
            // A more robust solution for dead players if phase doesn't change from 'voting' quickly
            // after deadline might be to navigate them to a generic waiting screen or directly to action.
            // Let's assume the phase *will* change to 'ejection' then 'action'.
            // So, the 'phase == ejection' or 'phase == action' checks above will handle their navigation.
            // We just need to show them the "You are dead" UI until then.
            print(
                "VotingScreen: Player is dead. Deadline passed. Waiting for phase change from 'voting'.");
          }

          // UI for dead players during the voting phase
          return Scaffold(
            key: const Key("dead_player_voting_screen"),
            appBar: AppBar(
              title: Text('Voting (Observer) - ${widget.playerName}'),
              centerTitle: true,
            ),
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'You are dead. You can’t vote.',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Waiting for voting to conclude...',
                    style: TextStyle(fontSize: 18, color: Colors.grey[700]),
                  ),
                  const SizedBox(height: 10),
                  if (secondsLeft > 0 &&
                      phase == 'voting') // Show countdown if relevant
                    Text(
                      'Time remaining: $secondsLeft seconds',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(),
                ],
              ),
            ),
          );
        }

        // --- Logic for Alive Players ---
        // If the deadline has passed AND the phase is still 'voting' (meaning backend hasn't updated phase yet)
        // alive players should be moved to a waiting state, then to EjectionScreen.
        // The MeetingWaitingScreen is designed for this.
        if (deadlineHasPassed && phase == 'voting' && !isDead) {
          _navigateOnce(MeetingWaitingScreen(
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            isHost: widget.isHost,
          ));
          return const Scaffold(body: Center(child: CircularProgressIndicator(
              key: Key("loading_meeting_waiting_deadline"))));
        }

        // Default UI for alive players to vote
        return Scaffold(
          key: const Key("alive_player_voting_screen"),
          appBar: AppBar(
            title: Text('Vote - ${widget.playerName}'),
            centerTitle: true,
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const SizedBox(height: 16),
                if (phase == 'voting') // Only show countdown if in voting phase
                  Text(
                    'Voting ends in $secondsLeft seconds...',
                    style: const TextStyle(fontSize: 24),
                  ),
                const SizedBox(height: 8),
                const Text(
                  'Vote for someone to eject',
                  style: TextStyle(fontSize: 20),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: ListView(
                    children: [
                      ...alivePlayers.map((name) =>
                          RadioListTile<String>(
                            value: name,
                            groupValue: selectedVote,
                            title: Text(name),
                            onChanged: hasVoted ? null : (val) =>
                                setState(() => selectedVote = val),
                          )),
                      RadioListTile<String>(
                        value: 'skip',
                        groupValue: selectedVote,
                        title: const Text('Skip Vote'),
                        onChanged: hasVoted ? null : (val) =>
                            setState(() => selectedVote = val),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: hasVoted || selectedVote == null ||
                      phase != 'voting'
                      ? null
                      : () async {
                    await gameRef.update(
                        {'votes.${widget.playerName}': selectedVote});
                    _navigateOnce(MeetingWaitingScreen(
                      roomCode: widget.roomCode,
                      playerName: widget.playerName,
                      isHost: widget.isHost,
                    ));
                  },
                  child: const Text('Submit Vote'),
                ),
              ],
            ),
          ),
        );
      },
    ),
    );
  }
}
class ActionRedirect extends StatelessWidget {
  final String roomCode;
  final String playerName;

  const ActionRedirect({required this.roomCode, required this.playerName, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Navigator.pushReplacementNamed(context, '/action', arguments: {
        'roomCode': roomCode,
        'playerName': playerName,
      });
    });
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}