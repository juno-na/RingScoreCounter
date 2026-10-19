class ShootingRound {
  const ShootingRound({
    required this.id,
    required this.capturedAt,
    required this.scores,
  });

  final int id;
  final DateTime capturedAt;
  final List<int> scores;

  int get total => scores.fold(0, (sum, score) => sum + score);
}

class ShootingDay {
  const ShootingDay({required this.date, required this.rounds});

  /// Stored as a local calendar date in YYYY-MM-DD form.
  final String date;
  final List<ShootingRound> rounds;

  int get total => rounds.fold(0, (sum, round) => sum + round.total);
}
