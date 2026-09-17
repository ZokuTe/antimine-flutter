import 'dart:io';

import 'package:antimine/foundation/io/save_file_manager.dart';
import 'package:antimine/common/models/difficulty.dart';
import 'package:antimine/common/models/file/save.dart';
import 'package:antimine/common/models/first_open.dart';
import 'package:antimine/common/models/game_status.dart';
import 'package:antimine/common/models/minefield.dart';
import 'package:antimine/foundation/uuid/uuid_generator.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uuid/uuid.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const savesN = 10;
  final UuidGenerator uuidGenerator = UuidGenerator();

  // The checked-in fixtures under test/helpers/fixtures are read-only inputs for
  // other test files. This test writes and deletes saves, so it must run against
  // its own copy: otherwise it destroys the shared fixtures and makes the suite
  // order-dependent.
  late Directory saveDirectory;
  late SaveFileManager saveFileManager;

  const fixtureNames = [
    'list',
    'stats',
    'ab7789f0-e396-4227-9a5e-68644f651c6c.save',
    'corrupt.save',
  ];

  setUp(() async {
    saveDirectory = await Directory.systemTemp.createTemp('antimine_saves');
    for (final name in fixtureNames) {
      await File('test/helpers/fixtures/$name')
          .copy('${saveDirectory.path}/$name');
    }
    saveFileManager = SaveFileManager(
      maxSaves: savesN,
      uuidGenerator: uuidGenerator,
      saveDirectory: Future.value(saveDirectory),
    );
    // Populate the manager's save-list cache from the copied fixtures so that
    // the on-disk state is visible to loadSaveList, matching what a real
    // application start would see.
    await saveFileManager.clearCache();
  });

  tearDown(() async {
    await saveFileManager.clearCache();
    if (saveDirectory.existsSync()) {
      await saveDirectory.delete(recursive: true);
    }
  });

  final save = SaveGame(
    id: 'test',
    seed: 100,
    startDate: 12345,
    duration: 8765431,
    minefield: const Minefield(seed: 4, width: 10, height: 10, mines: 9),
    difficulty: Difficulty.fixedSize,
    firstOpen: FirstOpen.unknown,
    status: GameStatus.inProgress,
    areas: const [],
    turns: 2,
  );

  test('loadSaveList', () async {
    final save = await saveFileManager.loadSaveList();
    expect(save.saves.length, 2);
  });

  test('load save', () async {
    final save = await saveFileManager.loadSave(
      'ab7789f0-e396-4227-9a5e-68644f651c6c',
    );
    expect(save, isNotNull);
    expect(save?.id, 'ab7789f0-e396-4227-9a5e-68644f651c6c');
  });

  test('load save invalid', () async {
    final save = await saveFileManager.loadSave('invalid');
    expect(save, isNull);
  });

  test('save game with valid content', () async {
    // When
    await saveFileManager.saveSave(save);

    // Then
    final saved = await saveFileManager.loadSave('test');
    expect(saved, isNotNull);
    expect(saved?.id, 'test');

    final list = await saveFileManager.loadSaveList();
    expect(list.saves.length, 3);
    expect(list.current, 'test');
    expect(list.saves.contains('test'), isTrue);
  });

  test('when saveId is null, should not save', () async {
    // Given
    final nullIdSave = save.withId(null);

    // When
    await saveFileManager.saveSave(nullIdSave);

    // Then
    final saved = await saveFileManager.loadSave('test');
    expect(saved, isNull);

    final list = await saveFileManager.loadSaveList();
    expect(list.saves.length, 2);
    expect(list.saves.contains('test'), isFalse);
  });

  test('delete save', () async {
    // Given
    await saveFileManager.saveSave(save);

    var saved = await saveFileManager.loadSave('test');
    expect(saved, isNotNull);
    expect(saved?.id, 'test');

    var list = await saveFileManager.loadSaveList();
    expect(list.saves.length, 3);
    expect(list.current, 'test');
    expect(list.saves.contains('test'), isTrue);

    // When
    await saveFileManager.deleteSave('test');

    // Then
    saved = await saveFileManager.loadSave('test');
    expect(saved, isNull);

    list = await saveFileManager.loadSaveList();
    expect(list.saves.length, 2);
    expect(list.saves.contains('test'), isFalse);
  });

  test('it can save up to X saves', () async {
    // Given
    final saveList = List.generate(
      savesN,
      (index) => save.withId("save_$index"),
    );

    // When
    for (final save in saveList) {
      await saveFileManager.saveSave(save);
    }

    // Then
    final list = await saveFileManager.loadSaveList();
    expect(list.saves.length, 10);
    expect(list.saves, {
      'save_${savesN - 10}',
      'save_${savesN - 9}',
      'save_${savesN - 8}',
      'save_${savesN - 7}',
      'save_${savesN - 6}',
      'save_${savesN - 5}',
      'save_${savesN - 4}',
      'save_${savesN - 3}',
      'save_${savesN - 2}',
      'save_${savesN - 1}',
    });
  });

  test('generateId returns valid UUID', () {
    // Given
    final saveId = saveFileManager.generateId();

    // Then
    expect(saveId, isNotNull);
    expect(saveId.length, 36);
    expect(saveId.contains('-'), isTrue);
    expect(Uuid.isValidUUID(fromString: saveId), isTrue);
  });

  test('generateId returns different values', () {
    // Given
    final saveId1 = saveFileManager.generateId();
    final saveId2 = saveFileManager.generateId();

    // Then
    expect(saveId1, isNot(saveId2));
  });
}
