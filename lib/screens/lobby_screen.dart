import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'role_reveal_screen.dart';
import 'action_phase_screen.dart';
import 'voting_screen.dart';

class LobbyScreen extends StatefulWidget {
  final String roomCode;
  final bool isHost;
  final String playerName;

  const LobbyScreen({
    required this.roomCode,
    required this.isHost,
    required this.playerName,
    super.key,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  int _imposterCount = 1;
  bool _hasNavigated = false;

  @override
  Widget build(BuildContext context) {
    final roomRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);

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
          title: Text('Lobby - ${widget.roomCode}'),
          centerTitle: true,
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: roomRef.snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

            final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
            final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
            final phase = data['phase'] as String? ?? 'waiting';
            final imposterCount = data['imposter_count'] as int? ?? 1;
            // Sync _imposterCount in state to Firestore
            if (_imposterCount != imposterCount) _imposterCount = imposterCount;

            void doNavigate(Widget Function() builder) {
              if (_hasNavigated) return;
              _hasNavigated = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (BuildContext context) => builder(),
                  ),
                );
              });
            }

            if (phase == 'role_reveal') {
              doNavigate(
                    () => RoleRevealScreen(roomCode: widget.roomCode, playerName: widget.playerName),
              );
            } else if (phase == 'action') {
              doNavigate(
                    () => ActionPhaseScreen(roomCode: widget.roomCode, playerName: widget.playerName),
              );
            } else if (phase == 'voting') {
              doNavigate(
                    () => VotingScreen(roomCode: widget.roomCode, playerName: widget.playerName),
              );
            }

            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  if (widget.isHost) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Recommended Imposter amounts: 4-8 players: 1, 9-11 players: 2, 12+ players: 3',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const Text(
                      'Number of Imposters:',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    DropdownButton<int>(
                      value: _imposterCount,
                      items: [1, 2, 3]
                          .map((v) => DropdownMenuItem<int>(value: v, child: Text('$v')))
                          .toList(),
                      onChanged: (newValue) {
                        if (newValue != null && newValue != _imposterCount) {
                          setState(() => _imposterCount = newValue);
                          roomRef.update({'imposter_count': newValue});
                        }
                      },
                    ),
                  ],
                  if (!widget.isHost)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8.0),
                      child: Text(
                        'Waiting for host to start game...',
                        style: TextStyle(fontSize: 15),
                      ),
                    ),
                  const SizedBox(height: 24),
                  const Text(
                    'Players in Room:',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Expanded(
                    child: players.isEmpty
                        ? const Center(child: Text('No players yet.'))
                        : ListView.builder(
                      itemCount: players.length,
                      itemBuilder: (context, idx) => ListTile(
                        leading: const Icon(Icons.person),
                        title: Text(players[idx]['name'] ?? '-'),
                      ),
                    ),
                  ),
                  const Text(
                    'How the Game works',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'If you are a crewmate, you try to vote out the imposter or complete all the tasks before they kill everyone! If you are an imposter, you try not to arouse suspicion and kill people until there is the same number of crewmates as imposters! Report dead bodies as you find them.',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.normal),
                  ),
                  if (widget.isHost)
                    ElevatedButton(
                      onPressed: players.length < _imposterCount + 1
                          ? null
                          : () async {
                        final names =
                        players.map((p) => p['name'].toString()).toList()..shuffle();
                        final assigned = names.asMap().entries.map((entry) {
                          final role = entry.key < _imposterCount ? 'imposter' : 'crewmate';
                          return {'name': entry.value, 'role': role};
                        }).toList();

                        await roomRef.update({
                          'players': assigned,
                          'phase': 'role_reveal',
                        });
                      },
                      child: Text(players.length < _imposterCount + 1
                          ? 'Need at least ${_imposterCount + 3} players'
                          : 'Start Game'),
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}