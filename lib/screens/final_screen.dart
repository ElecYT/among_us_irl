import 'package:flutter/material.dart';
import 'package:among_us_irl/main.dart';

class FinalScreen extends StatelessWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;
  final bool isCrewmatesWin;

  const FinalScreen({
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    required this.isCrewmatesWin,
    Key? key,
  }) : super(key: key);

  void _returnToHomeScreen(BuildContext context) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const HomeScreen()),
          (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black87,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isCrewmatesWin ? Icons.emoji_emotions : Icons.flash_on,
              size: 60,
              color: isCrewmatesWin ? Colors.greenAccent : Colors.redAccent,
            ),
            const SizedBox(height: 24),
            Text(
              isCrewmatesWin ? 'Crewmates Win!' : 'Imposters Win!',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              isCrewmatesWin
                  ? "The crewmates completed all their tasks or ejected all imposters!"
                  : "Imposters overran the ship. Better luck next time!",
              style: const TextStyle(fontSize: 18, color: Colors.white70),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _returnToHomeScreen(context),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey),
              child: const Text('Return to Main Menu'),
            ),
          ],
        ),
      ),
    );
  }
}