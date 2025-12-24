import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'lobby_screen.dart';
import 'role_reveal_screen.dart';
import 'action_phase_screen.dart';
import 'meeting_screen.dart';
import 'voting_screen.dart';
import 'meeting_waiting_screen.dart';
import 'ejection_screen.dart';
import 'final_screen.dart';

import 'game_referee.dart'; // adjust path if needed

class PhaseRouter extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const PhaseRouter({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.isHost,
  });

  @override
  State<PhaseRouter> createState() => _PhaseRouterState();
}

class _PhaseRouterState extends State<PhaseRouter> {
  GameReferee? _referee;

  @override
  void initState() {
    super.initState();
    if (widget.isHost) {
      _referee = GameReferee(roomCode: widget.roomCode)..start();
    }
  }

  @override
  void dispose() {
    _referee?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: roomRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() ?? {};
        final phase = (data['phase'] as String?) ?? 'waiting';
        debugPrint("ROUTE phase=$phase room=$widget.roomCode");
        switch (phase) {
          case 'waiting':
            return LobbyScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);

          case 'role_reveal':
            return RoleRevealScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);

          case 'action':
            return ActionPhaseScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);

          case 'meeting':
            return MeetingScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);

          case 'voting':
            return VotingScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);

        // Your code uses these as "go to ejection"
          case 'results':
            return EjectionScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);
          case 'ejection':
            return EjectionScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);

        // Your action screen sets this
          case 'crewmates_win':
            return const FinalScreen(
              isCrewWinner: true,
              message: 'Crewmates win!',
            );

          default:
          // Fallback so unknown phases don't crash the app
            return LobbyScreen(roomCode: widget.roomCode, playerName: widget.playerName, isHost: widget.isHost);
        }
      },
    );
  }
}