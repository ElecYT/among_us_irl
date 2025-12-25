import 'package:flutter/material.dart';

import 'voting_screen.dart';
import 'meeting_waiting_screen.dart';

class VotingStageScreen extends StatelessWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const VotingStageScreen({
    super.key,
    required this.roomCode,
    required this.playerName,
    required this.isHost,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // The actual voting UI people interact with
        VotingScreen(roomCode: roomCode, playerName: playerName, isHost: isHost),

        // The controller that ends voting (timer/all-voted) — must not block taps
        IgnorePointer(
          ignoring: true,
          child: Opacity(
            opacity: 0.0,
            child: MeetingWaitingScreen(
              roomCode: roomCode,
              playerName: playerName,
              isHost: isHost,
            ),
          ),
        ),
      ],
    );
  }
}
