import 'dart:math';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'report_body_screen.dart';
import 'meeting_screen.dart';

class ActionPhaseScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const ActionPhaseScreen({
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    super.key,
  });

  @override
  State<ActionPhaseScreen> createState() => _ActionPhaseScreenState();
}

class _ActionPhaseScreenState extends State<ActionPhaseScreen> {
  final List<String> allTasks = [
    'Test Back Door',
    'Test Front Door',
    'Test Upstairs Bathroom Sink',
    'Test Downstairs Bathroom Sink',
    'Test Kitchen Cabinet',
    'Test Garage Door (In basement)',
    'Test Hose (In the front yard)',
    'Sweep the perimeter of the house',
    'Close and open all downstairs doors',
    'Tell someone about your day',
    'Find towels in the Kitchen',
    'Find the back pantry',
    'Open all the kitchen cabinets',
    'Close all the kitchen cabinets',
    'Interrogate someone',
    'Take a 10 second nap on the couch',
    'Pickup something on the floor',
    'Find a red object',
  ];

  late final DocumentReference<Map<String, dynamic>> gameRef;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
  }

  Future<void> _callEmergencyMeeting() async {
    // Set meeting phase and called_by player in DB; MeetingScreen will pick this up
    await gameRef.update({
      'phase': 'meeting',
      'meeting_info': {
        'called_by': widget.playerName,
        'type': 'emergency',
        'timestamp': FieldValue.serverTimestamp(),
      },
    });
  }

  List<Map<String, dynamic>> generateRandomTasks() {
    final rand = Random();
    final shuffled = allTasks.toList()..shuffle(rand);
    return shuffled.take(6).map((task) => {'name': task, 'done': false}).toList();
  }

  Future<void> ensureTasksInitialized(List<Map<String, dynamic>> players) async {
    bool updated = false;

    final newPlayers = players.map((p) {
      if (p['name'] == widget.playerName && (p['tasks'] == null || p['tasks'].isEmpty)) {
        updated = true;
        return {
          ...p,
          'tasks': generateRandomTasks(),
        };
      }
      return p;
    }).toList();

    if (updated) {
      await gameRef.update({'players': newPlayers});
    }
  }

  Future<void> checkCrewmateWin(List<Map<String, dynamic>> players) async {
    final allDone = players.where((p) => p['role'] != 'imposter').every((p) {
      final tasks = List<Map<String, dynamic>>.from(p['tasks'] ?? []);
      return tasks.every((t) => t['done'] == true);
    });

    if (allDone) {
      await gameRef.update({'phase': 'crewmates_win'});
      final reportBodyScreen = ReportBodyScreen(
          roomCode: widget.roomCode, playerName: widget.playerName);
      reportBodyScreen.checkGameEnd(context, widget.roomCode);
    }
  }

  void _navigateToMeeting(BuildContext context) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => MeetingScreen(
          roomCode: widget.roomCode,
          playerName: widget.playerName,
          isHost: widget.isHost,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reportBodyScreen = ReportBodyScreen(roomCode: widget.roomCode, playerName: widget.playerName);
    reportBodyScreen.checkGameEnd(context, widget.roomCode);
    return Scaffold(
      appBar: AppBar(
        title: Text('Action Phase - ${widget.playerName}'),
        centerTitle: true,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: gameRef.snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() ?? {};
          final phase = data['phase'] as String? ?? '';
          final players = List<Map<String, dynamic>>.from(data['players'] ?? []);
          final currentPlayer = players.firstWhere(
                (p) => p['name'] == widget.playerName,
            orElse: () => {},
          );
          final isDead = currentPlayer['role'] == 'dead';
          final tasks = List<Map<String, dynamic>>.from(currentPlayer['tasks'] ?? []);

          // Ensure tasks are initialized
          ensureTasksInitialized(players);

          // If phase changed to meeting, auto-nav (once)
          if (phase == 'meeting') {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _navigateToMeeting(context);
            });
            return const Center(child: CircularProgressIndicator());
          }

          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Your goal as crewmate is to complete all tasks or vote out the imposter. Refrain from talking to crewmates, limiting discussion to meetings',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: isDead
                      ? null
                      : () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ReportBodyScreen(
                          roomCode: widget.roomCode,
                          playerName: widget.playerName,
                        ),
                      ),
                    );
                  },
                  child: const Text('Report Dead Body'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: isDead ? null : _callEmergencyMeeting,
                  child: const Text('Call Emergency Meeting'),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Your Tasks',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: tasks.length,
                    itemBuilder: (context, index) {
                      final task = tasks[index];
                      return CheckboxListTile(
                        title: Text(task['name']),
                        value: task['done'],
                        onChanged: isDead
                            ? null
                            : (bool? checked) async {
                          final updatedTask = {
                            ...task,
                            'done': checked ?? false,
                          };
                          final updatedTasks = [...tasks];
                          updatedTasks[index] = updatedTask;

                          final updatedPlayers = players.map((p) {
                            if (p['name'] == widget.playerName) {
                              return {
                                ...p,
                                'tasks': updatedTasks,
                              };
                            }
                            return p;
                          }).toList();

                          await gameRef.update({'players': updatedPlayers});
                          await checkCrewmateWin(updatedPlayers);
                        },
                      );
                    },
                  ),
                ),
                if (isDead)
                  const Padding(
                    padding: EdgeInsets.only(top: 32),
                    child: Text(
                      'You are dead. You cannot report/call meetings.',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}