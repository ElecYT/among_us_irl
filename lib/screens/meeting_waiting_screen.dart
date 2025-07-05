import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ejection_screen.dart';

class MeetingWaitingScreen extends StatefulWidget {
  final String roomCode;
  final String playerName;
  final bool isHost;

  const MeetingWaitingScreen({
    required this.roomCode,
    required this.playerName,
    required this.isHost,
    Key? key,
  }) : super(key: key);

  @override
  State<MeetingWaitingScreen> createState() => _MeetingWaitingScreenState();
}

class _MeetingWaitingScreenState extends State<MeetingWaitingScreen> {
  late final DocumentReference<Map<String, dynamic>> gameRef;
  Timer? countdownTimer;
  int secondsLeft = 70;
  bool _hasNavigated = false;

  @override
  void initState() {
    super.initState();
    gameRef = FirebaseFirestore.instance.collection('games').doc(widget.roomCode);
    _startCountdownAndMonitor();
  }

  void _startCountdownAndMonitor() async {
    try {
      final snapshot = await gameRef.get();
      final data = snapshot.data();

      if (data == null || !data.containsKey('voting_deadline') || data['voting_deadline'] is! String) {
        if (mounted) setState(() => secondsLeft = 60);
        return;
      }

      final deadlineStr = data['voting_deadline'] as String;
      final deadline = DateTime.tryParse(deadlineStr);
      if (deadline == null) {
        if (mounted) setState(() => secondsLeft = 60);
        return;
      }

      _updateSecondsLeft(deadline);

      countdownTimer?.cancel();
      countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        _updateSecondsLeft(deadline);

        if (secondsLeft <= 0) {
          timer.cancel();
          if (widget.isHost) {
            if (data['phase'] == 'voting' && widget.isHost) {
              await gameRef.update({'phase': 'ejection'});
            }
          }
        } else {
          final doc = await gameRef.get();
          final d = doc.data();
          if (d == null) return;

          final votes = Map<String, String>.from(d['votes'] ?? {});
          final players = List<Map<String, dynamic>>.from(d['players'] ?? []);
          final aliveCount = players.where((p) => p['role'] != 'dead').length;

          if (widget.isHost && votes.length >= aliveCount) {
            timer.cancel();
            if (data['phase'] == 'voting' && widget.isHost) {
              await gameRef.update({'phase': 'ejection'});
            }
          }
        }
      });
    } catch (_) {
      if (mounted) setState(() => secondsLeft = 60);
    }
  }

  void _updateSecondsLeft(DateTime deadline) {
    final now = DateTime.now();
    final diff = deadline.difference(now).inSeconds;
    setState(() {
      secondsLeft = diff > 0 ? diff : 0;
    });
  }

  void _navigateOnce(Widget targetScreen) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => targetScreen));
    });
  }

  @override
  void dispose() {
    countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: gameRef.snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final data = snapshot.data!.data() ?? {};
        final phase = data['phase'] ?? '';

        if ((phase == 'ejection' || phase == 'results') && !_hasNavigated) {
          _navigateOnce(EjectionScreen(
            roomCode: widget.roomCode,
            playerName: widget.playerName,
            isHost: widget.isHost,
          ));
          return const SizedBox();
        }

        return Scaffold(
          backgroundColor: Colors.black87,
          appBar: AppBar(
            title: Text('Waiting for Ejection - ${widget.playerName}'),
            centerTitle: true,
          ),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Waiting for others to finish voting...',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 20),
                Text(
                  'Time Remaining: $secondsLeft seconds',
                  style: const TextStyle(fontSize: 18, color: Colors.white70),
                ),
                const SizedBox(height: 20),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }
}