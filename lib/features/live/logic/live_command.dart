import '../../../common/models/input/action.dart';

/// 共享光标能移动的方向。
enum CursorDirection { up, down, left, right }

/// 一条弹幕能被解析成的指令。
///
/// 刻意只分两类：移动光标，或在光标处做一个动作。捣乱效果（画面抖动、遮挡之类）
/// 不在这里——那些是纯视觉的，不该经过游戏逻辑，由直播自己那层直接驱动 overlay。
sealed class LiveCommand {
  const LiveCommand();
}

/// 把共享光标往某个方向移动一格。
class MoveCursor extends LiveCommand {
  const MoveCursor(this.direction);

  final CursorDirection direction;

  @override
  bool operator ==(Object other) =>
      other is MoveCursor && other.direction == direction;

  @override
  int get hashCode => direction.hashCode;

  @override
  String toString() => 'MoveCursor(${direction.name})';
}

/// 在光标所在格子执行一个动作。
///
/// 复用游戏本来的 [Action] 枚举，所以这条指令可以原样喂给 `GameBloc` 的
/// `_handleAction`，走和主播点击完全相同的路径与判定。
class ActAtCursor extends LiveCommand {
  const ActAtCursor(this.action);

  final Action action;

  @override
  bool operator ==(Object other) =>
      other is ActAtCursor && other.action == action;

  @override
  int get hashCode => action.hashCode;

  @override
  String toString() => 'ActAtCursor(${action.name})';
}

/// 默认指令表。想改指令词只动这一处。
///
/// 键是**归一化之后**的弹幕文本（见 [LiveCommandParser.normalize]），所以要写小写。
/// 同一个指令可以挂多个词（比如 `上` 和 `w`）。
const Map<String, LiveCommand> defaultLiveVocabulary = {
  '上': MoveCursor(CursorDirection.up),
  'w': MoveCursor(CursorDirection.up),
  '下': MoveCursor(CursorDirection.down),
  's': MoveCursor(CursorDirection.down),
  '左': MoveCursor(CursorDirection.left),
  'a': MoveCursor(CursorDirection.left),
  '右': MoveCursor(CursorDirection.right),
  'd': MoveCursor(CursorDirection.right),
  '开': ActAtCursor(Action.open),
  '挖': ActAtCursor(Action.open),
  '旗': ActAtCursor(Action.flag),
  '插旗': ActAtCursor(Action.flag),
  '问': ActAtCursor(Action.question),
  '?': ActAtCursor(Action.question),
  '？': ActAtCursor(Action.question),
};

/// 把弹幕文本翻成一串操作。翻不出来就是 `null`，调用方直接忽略。
///
/// 一条弹幕可以是一整串操作，每个操作前面可以带一位数的次数：
///
/// | 弹幕 | 结果 |
/// | --- | --- |
/// | `下` | 下移一格 |
/// | `3下` | 下移三格 |
/// | `2右3下` | 右两格再下三格 |
/// | `3下开` | 下移三格，然后**在那一格**挖开 |
///
/// 次数在解析时就展开成重复的操作，所以调用方只要按顺序跑一遍。
/// 展开而不是把次数传下去，是因为 `3下开` 里的「开」必须落在移动之后的格子上，
/// 顺序执行天然就是这个语义。
///
/// **整条必须都能解析出来，解析到一半失败就整条丢弃。** 不能只执行认出来的
/// 前半截：观众得能预测自己那句话会干什么，部分执行会让「打错一个字」变成
/// 一个不可预期的副作用。
///
/// 也刻意不做模糊匹配——`开播了吗` 不因为含「开」就算指令。
class LiveCommandParser {
  const LiveCommandParser({this.vocabulary = defaultLiveVocabulary});

  final Map<String, LiveCommand> vocabulary;

  /// 一条弹幕最多能带多少个操作。
  ///
  /// B 站对弹幕长度本身有上限（普通 20 字、舰长 30 字），而每个操作至少占一个
  /// 字符，所以正常弹幕远到不了这里。这层只是兜底，防的是异常的输入源
  /// （比如被改过的桥）塞一条超长的串进来变出几十个排队动作。
  static const maxSteps = 32;

  /// 解析整条弹幕，成功返回按顺序展开的操作序列。
  List<LiveCommand>? parse(String text) {
    final source = normalize(text);
    if (source.isEmpty) {
      return null;
    }

    final longestKey = _longestKeyLength(vocabulary);
    final steps = <LiveCommand>[];
    var index = 0;

    while (index < source.length) {
      var count = 1;

      if (_isDigit(source[index])) {
        count = int.parse(source[index]);
        // 0 次不是一个有意义的操作。「10下」会在这里变成「1 次 + 剩下 `0下`」，
        // 而 `0下` 认不出来于是整条被丢——位数上限就是一位，这正是想要的。
        if (count == 0) {
          return null;
        }
        index++;
        if (index >= source.length) {
          // 只有数字，后面没有操作
          return null;
        }
      }

      final key = _longestKeyAt(source, index, longestKey);
      if (key == null) {
        return null;
      }

      final command = vocabulary[key]!;
      for (var repeat = 0; repeat < count; repeat++) {
        if (steps.length >= maxSteps) {
          return null;
        }
        steps.add(command);
      }

      index += key.length;
    }

    return steps;
  }

  /// 在 [index] 处找最长的指令词。
  ///
  /// 从长到短试：`插旗` 是两字词而 `插` 单独不是词，反过来也可能存在短词是长词
  /// 前缀的情况，所以按长度降序找第一个命中才稳。
  String? _longestKeyAt(String source, int index, int longestKey) {
    final maxLength = (source.length - index).clamp(1, longestKey);
    for (var length = maxLength; length >= 1; length--) {
      final candidate = source.substring(index, index + length);
      if (vocabulary.containsKey(candidate)) {
        return candidate;
      }
    }
    return null;
  }

  /// 去掉**所有**空白（含制表、换行、全角空格）和零宽字符，然后转小写。
  ///
  /// 允许串里夹空白，所以 `2 右 3 下` 和 `2右3下` 等价。从输入法粘贴过来的
  /// 弹幕里这两种很常见，不清掉会被当成两条不同的指令。
  static String normalize(String text) {
    return text
        // Dart 的 \s 覆盖 ASCII 空格/制表/换行，也覆盖 U+3000 全角空格和 U+FEFF
        .replaceAll(RegExp(r'\s'), '')
        // 零宽空格不在 \s 里，得单独清
        .replaceAll('\u200B', '')
        .toLowerCase();
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}

int _longestKeyLength(Map<String, LiveCommand> vocabulary) {
  var longest = 1;
  for (final key in vocabulary.keys) {
    if (key.length > longest) {
      longest = key.length;
    }
  }
  return longest;
}
