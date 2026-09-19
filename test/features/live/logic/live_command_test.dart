import 'package:antimine/common/models/input/action.dart';
import 'package:antimine/features/live/logic/live_command.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = LiveCommandParser();

  List<LiveCommand>? parse(String text) => parser.parse(text);

  const up = MoveCursor(CursorDirection.up);
  const down = MoveCursor(CursorDirection.down);
  const left = MoveCursor(CursorDirection.left);
  const right = MoveCursor(CursorDirection.right);
  const open = ActAtCursor(Action.open);
  const flag = ActAtCursor(Action.flag);

  group('normalize', () {
    test('去掉首尾空白', () {
      expect(LiveCommandParser.normalize('  开  '), '开');
    });

    test('串中间的空白也清掉', () {
      // 允许串里夹空白，`2 右 3 下` 和 `2右3下` 等价
      expect(LiveCommandParser.normalize('2 右 3 下'), '2右3下');
      expect(LiveCommandParser.normalize('2\t右\n3下'), '2右3下');
      expect(LiveCommandParser.normalize('2\u3000右'), '2右');
    });

    test('抹掉零宽字符', () {
      expect(LiveCommandParser.normalize('\u200B开'), '开');
      expect(LiveCommandParser.normalize('开\u200B'), '开');
    });

    test('转小写', () {
      expect(LiveCommandParser.normalize('W'), 'w');
    });

    test('全空白归一成空串', () {
      expect(LiveCommandParser.normalize('   '), '');
      expect(LiveCommandParser.normalize('\u3000\u200B'), '');
    });
  });

  group('单个操作', () {
    test('四个方向', () {
      expect(parse('上'), const [up]);
      expect(parse('下'), const [down]);
      expect(parse('左'), const [left]);
      expect(parse('右'), const [right]);
    });

    test('WASD 也行', () {
      expect(parse('w'), const [up]);
      expect(parse('a'), const [left]);
      expect(parse('D'), const [right]);
    });

    test('动作映射到游戏已有的 Action 枚举', () {
      expect(parse('开'), const [open]);
      expect(parse('挖'), const [open]);
      expect(parse('旗'), const [flag]);
      expect(parse('问'), const [ActAtCursor(Action.question)]);
    });

    test('两字指令按最长匹配', () {
      // `插` 单独不是词，所以必须匹配到 `插旗`
      expect(parse('插旗'), const [flag]);
    });

    test('半角和全角问号都认', () {
      expect(parse('?'), const [ActAtCursor(Action.question)]);
      expect(parse('？'), const [ActAtCursor(Action.question)]);
    });
  });

  group('次数', () {
    test('3下 就是下移三格', () {
      expect(parse('3下'), const [down, down, down]);
    });

    test('1 和不写等价', () {
      expect(parse('1右'), parse('右'));
    });

    test('9 是上限，合法', () {
      expect(parse('9右'), const [
        right,
        right,
        right,
        right,
        right,
        right,
        right,
        right,
        right,
      ]);
    });

    test('每个方向都能带次数', () {
      expect(parse('2上'), const [up, up]);
      expect(parse('2左'), const [left, left]);
      expect(parse('2w'), const [up, up]);
    });

    test('次数也能加在两字指令上', () {
      expect(parse('3插旗'), const [flag, flag, flag]);
    });

    test('动作带次数就是重复做', () {
      expect(parse('3开'), const [open, open, open]);
    });
  });

  group('一串操作', () {
    test('2右3下', () {
      expect(parse('2右3下'), const [right, right, down, down, down]);
    });

    test('不带次数的多个移动', () {
      expect(parse('右右左'), const [right, right, left]);
    });

    test('移动和动作混着来，顺序保留', () {
      expect(parse('右开'), const [right, open]);
      expect(parse('开右'), const [open, right]);
    });

    test('动作可以出现多次', () {
      expect(parse('开旗'), const [open, flag]);
    });

    test('夹空白的串等价于紧凑的串', () {
      expect(parse('2 右 3 下'), parse('2右3下'));
    });

    test('长串', () {
      // 3下 → (5,8)，开在那一格；再 2右，再开
      expect(parse('3下开2右开'), const [
        down,
        down,
        down,
        open,
        right,
        right,
        open,
      ]);
    });
  });

  group('整条必须都能解析，否则整条丢弃', () {
    test('尾巴上有认不出的字', () {
      expect(parse('右x'), isNull);
    });

    test('中间有认不出的字', () {
      // 不能只执行前半截——打错一个字不该变成不可预期的副作用
      expect(parse('2右x开'), isNull);
    });

    test('不相干的闲聊', () {
      expect(parse('主播加油'), isNull);
      expect(parse('哈哈哈'), isNull);
    });

    test('不做子串匹配——句子里带「开」不算', () {
      expect(parse('开播了吗'), isNull);
      expect(parse('开开心心'), isNull);
    });

    test('空串和纯空白', () {
      expect(parse(''), isNull);
      expect(parse('   '), isNull);
    });
  });

  group('次数只能是一位数', () {
    test('0 次不算操作', () {
      expect(parse('0下'), isNull);
      expect(parse('0右开'), isNull);
    });

    test('两位数被拒', () {
      // 「1 次」之后剩下 `0下`，认不出来，于是整条丢
      expect(parse('10下'), isNull);
      expect(parse('20'), isNull);
    });

    test('只有数字没有操作', () {
      expect(parse('3'), isNull);
      expect(parse('9'), isNull);
    });

    test('数字后面跟着认不出的字', () {
      expect(parse('3x'), isNull);
    });
  });

  group('操作数量上限', () {
    test('刚好到上限可以', () {
      // 9+9+9+3 = 30，没超 32
      expect(parse('9右9右9右3右')!.length, 30);
    });

    test('超了就整条丢弃', () {
      // 9*4 = 36
      expect(parse('9右9右9右9右'), isNull);
      expect(LiveCommandParser.maxSteps, 32);
    });
  });

  group('指令表可替换', () {
    test('自定义词表覆盖默认词表', () {
      const custom = LiveCommandParser(vocabulary: {'gogo': up});
      expect(custom.parse('gogo'), const [up]);
      expect(custom.parse('2gogo'), const [up, up]);
      // 默认词表里的词在自定义词表下失效
      expect(custom.parse('上'), isNull);
    });
  });
}
