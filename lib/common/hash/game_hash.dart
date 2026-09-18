import 'package:equatable/equatable.dart';

import '../models/minefield.dart';

class GameHash extends Equatable {
  GameHash({
    required this.hash,
    required this.minefield,
    required this.initX,
    required this.initY,
  }) : _parts = hash.split(':');

  final String hash;
  final Minefield minefield;
  final int initX;
  final int initY;

  final List<String> _parts;

  String get hashBase => _parts.first;
  String get hashSeed => _parts[1];

  @override
  List<Object?> get props => [minefield, initX, initY];
}
