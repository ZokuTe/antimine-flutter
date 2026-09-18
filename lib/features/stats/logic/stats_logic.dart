import '../../../common/models/stats.dart';

/// Aggregates a set of finished games.
///
/// [StatsSummary.of] walks the input once. Callers pass lazy iterables (the
/// stats screen filters the same list nine times over), and every helper here
/// used to re-walk its input, so a board with one set of statistics was scanned
/// a dozen times to render a single row.
class StatsSummary {
  const StatsSummary({
    required this.gamesPlayed,
    required this.victories,
    required this.totalMines,
    required this.totalTimeVictories,
    required this.totalTime,
    required this.bestTime,
    required this.openedCells,
  });

  final int gamesPlayed;
  final int victories;
  final int totalMines;
  final int totalTimeVictories;
  final int totalTime;

  /// Fastest victory in milliseconds, or null when there is none.
  final int? bestTime;
  final int openedCells;

  /// Average victory time in milliseconds, or 0 when there is no victory.
  int get averageTime => totalTimeVictories ~/ (victories == 0 ? 1 : victories);

  double get winPercentage =>
      (victories / (gamesPlayed == 0 ? 1 : gamesPlayed)) * 100;

  static StatsSummary of(Iterable<Stats> stats) {
    var gamesPlayed = 0;
    var victories = 0;
    var totalMines = 0;
    var totalTimeVictories = 0;
    var totalTime = 0;
    int? bestTime;
    var openedCells = 0;

    for (final entry in stats) {
      gamesPlayed++;
      totalTime += entry.duration;
      openedCells += entry.openArea;

      if (entry.victory != 1) {
        continue;
      }

      victories++;
      totalMines += entry.mines;
      totalTimeVictories += entry.duration;
      final previousBest = bestTime;
      if (previousBest == null || entry.duration < previousBest) {
        bestTime = entry.duration;
      }
    }

    return StatsSummary(
      gamesPlayed: gamesPlayed,
      victories: victories,
      totalMines: totalMines,
      totalTimeVictories: totalTimeVictories,
      totalTime: totalTime,
      bestTime: bestTime,
      openedCells: openedCells,
    );
  }
}
