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

class PhaseRouter extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('games').doc(roomCode);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: roomRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() ?? {};
        final phase = (data['phase'] as String?) ?? 'waiting';

        switch (phase) {
          case 'waiting':
            return LobbyScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);

          case 'role_reveal':
            return RoleRevealScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);

          case 'action':
            return ActionPhaseScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);

          case 'meeting':
            return MeetingScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);

          case 'voting':
            return VotingScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);

        // Your code uses these as "go to ejection"
          case 'results':
            return EjectionScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);
          case 'ejection':
            return EjectionScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);

        // Your action screen sets this
          case 'crewmates_win':
            return const FinalScreen(
              isCrewWinner: true,
              message: 'Crewmates win!',
            );

          default:
          // Fallback so unknown phases don't crash the app
            return LobbyScreen(roomCode: roomCode, playerName: playerName, isHost: isHost);
        }
      },
    );
  }
}