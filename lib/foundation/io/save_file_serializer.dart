import 'dart:typed_data';

import '../../common/models/area.dart';
import '../../common/models/difficulty.dart';
import '../../common/models/file/save.dart';
import '../../common/models/first_open.dart';
import '../../common/models/game_status.dart';
import '../../common/models/mark.dart';
import '../../common/models/minefield.dart';
import '../../common/models/neighbours.dart';
import 'file_byte_reader.dart';
import 'file_byte_writer.dart';

class SaveFileSerializer {
  /// Reads a save game from a byte list.
  /// Return null if the save game is invalid.
  static SaveGame? fromUint8List(String? id, Uint8List bytes) {
    try {
      FileByteReader reader = FileByteReader(bytes);

      final seed = reader.readLong();
      final startDate = reader.readLong();
      final duration = reader.readLong();
      final difficulty = Difficulty.values.elementAt(reader.readInt());
      final firstOpen = FirstOpen(initialId: reader.readInt());
      final status = GameStatus.fromId(reader.readInt());
      final turns = reader.readInt();
      final minefield = Minefield(
        width: reader.readInt(),
        height: reader.readInt(),
        mines: reader.readInt(),
        seed: reader.readLong(),
      );

      final areaSize = reader.readInt();
      final areaList = List<Area>.generate(areaSize, (index) {
        return Area(
          id: reader.readInt(),
          x: reader.readInt(),
          y: reader.readInt(),
          minesAround: reader.readInt(),
          hasMine: reader.readBool(),
          ignoreError: reader.readBool(),
          covered: reader.readBool(),
          mark: Mark.fromId(reader.readInt()),
          revealed: reader.readBool(),
          // The stored neighbor ids carry no direction, and `neighbours` is
          // rebuilt from the board geometry when the save is loaded
          // (`MinefieldHandler.loadFromList`). The list is still consumed so
          // the cursor stays aligned.
          neighbours: _consumeNeighbours(reader),
          dimNumber: reader.readBool(),
        );
      });

      return SaveGame(
        id: id,
        seed: seed,
        startDate: startDate,
        duration: duration,
        difficulty: difficulty,
        firstOpen: firstOpen,
        status: status,
        turns: turns,
        minefield: minefield,
        areas: areaList,
      );
    } catch (e) {
      return null;
    }
  }

  static Uint8List toUint8List(SaveGame save) {
    final writer = FileByteWriter();

    writer.writeLong(save.seed);
    writer.writeLong(save.startDate);
    writer.writeLong(save.duration);
    writer.writeInt(save.difficulty.index);
    writer.writeInt(save.firstOpen.initialId ?? FirstOpen.unknownId);
    writer.writeInt(save.status.id);
    writer.writeInt(save.turns);
    writer.writeInt(save.minefield.width);
    writer.writeInt(save.minefield.height);
    writer.writeInt(save.minefield.mines);
    writer.writeLong(save.minefield.seed);

    writer.writeInt(save.areas.length);
    for (final area in save.areas) {
      writer.writeInt(area.id);
      writer.writeInt(area.x);
      writer.writeInt(area.y);
      writer.writeInt(area.minesAround);
      writer.writeBool(area.hasMine);
      writer.writeBool(area.ignoreError);
      writer.writeBool(area.covered);
      writer.writeInt(area.mark.mask);
      writer.writeBool(area.revealed);
      writer.writeInt(area.neighbours.list.length);
      for (final neighbour in area.neighbours.list) {
        writer.writeInt(neighbour);
      }
      writer.writeBool(area.dimNumber);
    }
    return writer.bytes;
  }

  /// Reads and discards a stored neighbour id list.
  ///
  /// The ids are positional-only, so they cannot be mapped back onto the eight
  /// named neighbours; the list exists in the format to keep the reader's
  /// cursor aligned, and `MinefieldHandler.loadFromList` derives the real
  /// neighbours from the board dimensions.
  static Neighbours _consumeNeighbours(FileByteReader reader) {
    final count = reader.readInt();
    for (var i = 0; i < count; i++) {
      reader.readInt();
    }
    return const Neighbours();
  }
}
