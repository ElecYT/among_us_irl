import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

import 'screens/host_game_screen.dart';
import 'screens/join_game_screen.dart';
import 'screens/action_phase_screen.dart'; // Change to 'action_phase_screen.dart' and ActionPhaseScreen if you update filenames/classes

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
    home: MaterialApp(
      title: 'Among Us IRL',
      debugShowCheckedModeBanner: false,
      // You can use routes/table here, or just use push with MaterialPageRoute as elsewhere.
      onGenerateRoute: (settings) {
        // Handle named navigation with arguments
        if (settings.name == '/action') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => ActionPhaseScreen( // Change to ActionPhaseScreen if you rename!
              roomCode: args['roomCode'],
              playerName: args['playerName'],
              isHost: args['isHost'],
            ),
          );
        }
        return null; // uses home otherwise
      },
      home: const HomeScreen(),
    ),
    );
  }
}

// Consider moving this out to screens/home_screen.dart for modularity
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
        title: const Text('Among Us IRL'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Play Among Us in Real Life!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
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
    ),
    );
  }
}