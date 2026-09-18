import 'package:equatable/equatable.dart';

/// The ids of the up-to-eight areas surrounding one cell.
///
/// The ids are stored as fields so `props` lists them individually (and so the
/// class stays `const`-constructible). [list] is the derived view callers
/// iterate; it is computed on demand because most cells never need it, and the
/// alternative — storing the list alongside these fields — duplicates the same
/// eight integers on every cell of the board.
class Neighbours extends Equatable {
  final int topId;
  final int bottomId;
  final int leftId;
  final int rightId;
  final int topLeftId;
  final int topRightId;
  final int bottomLeftId;
  final int bottomRightId;

  const Neighbours({
    this.topId = noLink,
    this.bottomId = noLink,
    this.leftId = noLink,
    this.rightId = noLink,
    this.topLeftId = noLink,
    this.topRightId = noLink,
    this.bottomLeftId = noLink,
    this.bottomRightId = noLink,
  });

  List<int> get list {
    final neighbours = <int>[];
    for (final id in [
      topId,
      bottomId,
      leftId,
      rightId,
      topLeftId,
      topRightId,
      bottomLeftId,
      bottomRightId,
    ]) {
      if (id >= 0) {
        neighbours.add(id);
      }
    }
    return neighbours;
  }

  @override
  List<Object?> get props => [
    topId,
    bottomId,
    leftId,
    rightId,
    topLeftId,
    topRightId,
    bottomLeftId,
    bottomRightId,
  ];

  @override
  bool get stringify => true;

  static const int noLink = -1;
}
