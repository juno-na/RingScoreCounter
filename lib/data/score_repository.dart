import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/shooting_round.dart';

class ScoreRepository {
  Database? _database;

  Future<void> open() async {
    final directory = await getApplicationSupportDirectory();
    final dbPath = p.join(directory.path, 'ring_score.db');
    _database = await openDatabase(
      dbPath,
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE shooting_rounds (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            local_date TEXT NOT NULL,
            captured_at INTEGER NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE arrow_scores (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            round_id INTEGER NOT NULL REFERENCES shooting_rounds(id) ON DELETE CASCADE,
            ordinal INTEGER NOT NULL,
            score INTEGER NOT NULL CHECK (score BETWEEN 0 AND 10),
            UNIQUE(round_id, ordinal)
          )
        ''');
        await db.execute(
          'CREATE INDEX rounds_by_date ON shooting_rounds(local_date, captured_at)',
        );
      },
    );
  }

  Database get _db {
    final database = _database;
    if (database == null) throw StateError('Score database is not open.');
    return database;
  }

  Future<List<ShootingDay>> loadDays() async {
    final rows = await _db.rawQuery('''
      SELECT r.id, r.local_date, r.captured_at, a.ordinal, a.score
      FROM shooting_rounds AS r
      LEFT JOIN arrow_scores AS a ON a.round_id = r.id
      ORDER BY r.local_date DESC, r.captured_at DESC, a.ordinal ASC
    ''');
    final grouped = <String, List<ShootingRound>>{};
    final roundData = <int, ({DateTime capturedAt, List<int> scores})>{};
    for (final row in rows) {
      final date = row['local_date'] as String;
      final id = row['id'] as int;
      final details = roundData.putIfAbsent(
        id,
        () => (
          capturedAt: DateTime.fromMillisecondsSinceEpoch(
            row['captured_at'] as int,
          ),
          scores: <int>[],
        ),
      );
      if (row['score'] != null) details.scores.add(row['score'] as int);
      if (row['ordinal'] == null) {
        grouped.putIfAbsent(date, () => []);
      } else if (!grouped.containsKey(date)) {
        grouped[date] = [];
      }
    }
    for (final row in rows) {
      final date = row['local_date'] as String;
      final id = row['id'] as int;
      final details = roundData[id]!;
      final rounds = grouped.putIfAbsent(date, () => []);
      if (!rounds.any((round) => round.id == id)) {
        rounds.add(ShootingRound(
          id: id,
          capturedAt: details.capturedAt,
          scores: details.scores,
        ));
      }
    }
    return grouped.entries
        .map((entry) => ShootingDay(date: entry.key, rounds: entry.value))
        .toList(growable: false);
  }

  Future<void> saveRound({
    required DateTime capturedAt,
    required List<int> scores,
  }) async {
    if (scores.isEmpty || scores.any((score) => score < 0 || score > 10)) {
      throw ArgumentError.value(scores, 'scores', 'Use one or more scores from 0 to 10.');
    }
    final local = capturedAt.toLocal();
    final localDate =
        '${local.year.toString().padLeft(4, '0')}-'
        '${local.month.toString().padLeft(2, '0')}-'
        '${local.day.toString().padLeft(2, '0')}';
    await _db.transaction((transaction) async {
      final roundId = await transaction.insert('shooting_rounds', {
        'local_date': localDate,
        'captured_at': capturedAt.millisecondsSinceEpoch,
      });
      final batch = transaction.batch();
      for (var index = 0; index < scores.length; index++) {
        batch.insert('arrow_scores', {
          'round_id': roundId,
          'ordinal': index,
          'score': scores[index],
        });
      }
      await batch.commit(noResult: true);
    });
  }

  Future<void> deleteRound(int id) async {
    await _db.delete('shooting_rounds', where: 'id = ?', whereArgs: [id]);
  }
}
