import 'package:among_us_irl/main.dart';
import 'package:flutter/material.dart';

class FinalScreen extends StatelessWidget {
  final bool isCrewWinner;
  final String message;

  const FinalScreen({required this.isCrewWinner, required this.message, super.key});

  void _returnToHomeScreen(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isCrewWinner ? 'Crewmates Win!' : 'Imposters Win!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            Text(message, style: TextStyle(fontSize: 18)),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () => _returnToHomeScreen(context),
              child: const Text('Return to Main Menu'),
            ),
          ],
        ),
      ),
    );
  }
}