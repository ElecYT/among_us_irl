import 'package:among_us_irl/screens/ejection_screen.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/host_game_screen.dart';
import 'screens/join_game_screen.dart';
import 'screens/action_phase_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const AmongUsApp());
}

class AmongUsApp extends StatelessWidget {
  const AmongUsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Among Us IRL',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.grey,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: Colors.black87,
        cardColor: Colors.blueGrey[900],
        textTheme: const TextTheme(
          bodyLarge: TextStyle(color: Colors.white),
          bodySmall: TextStyle(color: Colors.white70),
          bodyMedium: TextStyle(color: Colors.white70),
          titleLarge: TextStyle(color: Colors.white70),
          titleMedium: TextStyle(color: Colors.white70),
          titleSmall: TextStyle(color: Colors.white70),
        ),
      ),
      home: const HomeScreen(),
      onGenerateRoute: (settings) {
        final args = settings.arguments as Map<String, dynamic>?;

        if (settings.name == '/action' && args != null) {
          return MaterialPageRoute(
            builder: (_) => ActionPhaseScreen(
              roomCode: args['roomCode'],
              playerName: args['playerName'],
              isHost: args['isHost'],
            ),
          );
        }
        if (settings.name == '/ejection' && args != null) {
          return MaterialPageRoute(
            builder: (_) => EjectionScreen(
              roomCode: args['roomCode'],
              playerName: args['playerName'],
              isHost: args['isHost'],
            ),
          );
        }
        // Add more routes as needed
        return null;
      },
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _hostGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HostGameScreen()),
    );
  }

  void _joinGame(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const JoinGameScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Among Us IRL - beta-0.8.1'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Play Among Us in Real Life!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              const Text(
                'Get ready for an epic game of Among Us played in real life! Complete tasks, kill players (if you\'re the imposter), and vote out players to win the game.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: () => _hostGame(context),
                child: const Text('Host Game'),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => _joinGame(context),
                child: const Text('Join Game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}