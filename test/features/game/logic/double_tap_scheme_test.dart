import 'package:antimine/common/models/input/game_input.dart';
import 'package:antimine/common/models/input/input_type.dart';
import 'package:flutter_test/flutter_test.dart';

/// Whether double-tapping reaches an action no other bound gesture does.
///
/// Mirrors `GameRenderer._schemeNeedsDoubleTap`. Duplicated here because the
/// renderer cannot be constructed without a full Flame game, and this rule is
/// what decides whether every tap in the game waits out the double-tap
/// timeout.
bool schemeNeedsDoubleTap(int controlType) {
  final map = GameInput.fromId(controlType).inputMap;
  final doubleTap = map[InputType.doubleTap];
  if (doubleTap == null) {
    return false;
  }
  return doubleTap != map[InputType.singleTap] &&
      doubleTap != map[InputType.longTap];
}

void main() {
  test('only schemes whose double tap is unreachable keep the recognizer', () {
    // A scheme that binds double tap to an action single tap already performs
    // gains nothing from the gesture, and keeping the recognizer would make
    // every tap wait out kDoubleTapTimeout.
    expect(schemeNeedsDoubleTap(GameInput.type1.id), isFalse);
    expect(schemeNeedsDoubleTap(GameInput.type2.id), isFalse);

    // Here double tap is the only route to one of the two actions.
    expect(schemeNeedsDoubleTap(GameInput.type3.id), isTrue);
    expect(schemeNeedsDoubleTap(GameInput.type4.id), isTrue);

    // The selector scheme binds nothing at all.
    expect(schemeNeedsDoubleTap(GameInput.type5.id), isFalse);
  });

  test('an unknown scheme id falls back without needing the recognizer', () {
    expect(schemeNeedsDoubleTap(-1), isFalse);
  });
}
