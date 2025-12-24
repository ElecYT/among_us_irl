import 'package:cloud_firestore/cloud_firestore.dart';

class GameReferee {
  final FirebaseFirestore _db;
  final String roomCode;

  bool _isRunning = false;
  bool _isResolving = false;
  int? _lastResolvedId;

  GameReferee({
    FirebaseFirestore? firestore,
    required this.roomCode,
  }) : _db = firestore ?? FirebaseFirestore.instance;

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    final roomRef = _db.collection('games').doc(roomCode);

    roomRef.snapshots().listen((snap) async {
      if (!_isRunning) return;
      final data = snap.data() as Map<String, dynamic>?;
      if (data == null) return;

      final phase = (data['phase'] as String?) ?? '';
      final state = (data['resolutionState'] as String?) ?? '';
      final resId = (data['resolutionId'] as int?) ?? 0;

      if (phase != 'ejection_pending') return;
      if (state != 'pending') return;

      // Prevent re-entrancy / duplicate resolves on the host device
      if (_isResolving) return;
      if (_lastResolvedId != null && _lastResolvedId == resId) return;

      _isResolving = true;
      try {
        await _resolve(resId);
        _lastResolvedId = resId;
      } finally {
        _isResolving = false;
      }
    });
  }

  void stop() {
    _isRunning = false;
  }

  Future<void> _resolve(int expectedResolutionId) async {
    final roomRef = _db.collection('games').doc(roomCode);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(roomRef);
      final data = snap.data() as Map<String, dynamic>? ?? {};

      final phase = (data['phase'] as String?) ?? '';
      final state = (data['resolutionState'] as String?) ?? '';
      final resId = (data['resolutionId'] as int?) ?? 0;

      // Idempotency guard (server-side)
      if (phase != 'ejection_pending') return;
      if (state != 'pending') return;
      if (resId != expectedResolutionId) return;

      final playersRaw = (data['players'] as List?) ?? const [];
      final votesRaw = (data['votes'] as Map?) ?? const {};

      final players = playersRaw
          .whereType<Map>()
          .map((m) => Map<String, dynamic>.from(m))
          .toList();

      // --- Helpers to interpret your current player schema safely ---
      String? idOf(Map<String, dynamic> p) =>
          (p['id'] ?? p['playerId'] ?? p['uid'])?.toString();

      bool isAlive(Map<String, dynamic> p) {
        if (p.containsKey('isAlive')) return p['isAlive'] == true;
        final role = (p['role'] ?? '').toString();
        return role != 'dead';
      }

      bool isImpostor(Map<String, dynamic> p) {
        if (p.containsKey('isImpostor')) return p['isImpostor'] == true;
        final role = (p['role'] ?? '').toString();
        return role == 'impostor';
      }

      final aliveIds = <String>{};
      for (final p in players) {
        final pid = idOf(p);
        if (pid == null) continue;
        if (isAlive(p)) aliveIds.add(pid);
      }

      // votes: Map<voterId, targetId | "skip">
      final votes = <String, String>{};
      for (final e in votesRaw.entries) {
        final voter = e.key?.toString();
        final choice = e.value?.toString();
        if (voter == null || choice == null) continue;
        votes[voter] = choice;
      }

      // Count votes from alive voters only
      final counts = <String, int>{};
      votes.forEach((voterId, choice) {
        if (!aliveIds.contains(voterId)) return;
        counts[choice] = (counts[choice] ?? 0) + 1;
      });

      final skipCount = counts['skip'] ?? 0;

      // Find top non-skip choice + tie detection
      String? topTargetId;
      int topVotes = 0;
      bool tie = false;

      counts.forEach((choice, c) {
        if (choice == 'skip') return;
        if (c > topVotes) {
          topVotes = c;
          topTargetId = choice;
          tie = false;
        } else if (c == topVotes && c != 0) {
          tie = true;
        }
      });

      // Among Us-style rule: tie OR skip >= topVotes => no ejection
      final shouldEject =
          !tie && topTargetId != null && topVotes > 0 && skipCount < topVotes;

      String? ejectedId;
      String reason;

      if (!shouldEject) {
        ejectedId = null;
        reason = tie ? 'tie' : 'skip';
      } else {
        ejectedId = topTargetId;
        reason = 'majority';
      }

      // Apply ejection (mark dead)
      List<Map<String, dynamic>> updatedPlayers = players;
      if (ejectedId != null) {
        updatedPlayers = players.map((p) {
          final pid = idOf(p);
          if (pid == ejectedId) {
            // Preserve your schema: set isAlive=false if present, else role='dead'
            if (p.containsKey('isAlive')) {
              return <String, dynamic>{...p, 'isAlive': false};
            }
            return <String, dynamic>{...p, 'role': 'dead'};
          }
          return p;
        }).toList();
      }

      // Check win condition (explicit)
      int aliveImpostors = 0;
      int aliveCrew = 0;

      for (final p in updatedPlayers) {
        if (!isAlive(p)) continue;
        if (isImpostor(p)) {
          aliveImpostors += 1;
        } else {
          aliveCrew += 1;
        }
      }

      String? winner;
      String nextPhase;

      if (aliveImpostors == 0) {
        winner = 'crew';
        nextPhase = 'game_over';
      } else if (aliveImpostors >= aliveCrew) {
        winner = 'impostor';
        nextPhase = 'game_over';
      } else {
        winner = null;
        nextPhase = 'ejection'; // show ejection screen next
      }

      txn.update(roomRef, {
        'players': updatedPlayers,
        'votes': {},

        'ejection': {
          'ejectedPlayerId': ejectedId,
          'reason': reason,
          // optional but useful for debugging:
          'voteCounts': counts,
          'resolutionId': resId,
        },

        'winner': winner,
        'resolutionState': 'resolved',
        'phase': nextPhase,
      });
    });
  }
}
