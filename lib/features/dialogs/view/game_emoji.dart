import 'dart:math';

import 'package:flutter/material.dart';

import '../../../foundation/ui/spacing.dart';

class GameEmoji extends StatefulWidget {
  const GameEmoji({super.key, required this.emojis});

  final List<String> emojis;

  static final Random _random = Random();

  /// Picks an emoji other than [filter] when the list offers one.
  String randomEmoji({String? filter}) {
    final candidates =
        filter == null
            ? emojis
            : emojis.where((emoji) => emoji != filter).toList();
    final pool = candidates.isEmpty ? emojis : candidates;
    return pool[_random.nextInt(pool.length)];
  }

  @override
  State<StatefulWidget> createState() {
    return _GameEmojiState();
  }
}

class _GameEmojiState extends State<GameEmoji> {
  late String _emoji;

  @override
  void initState() {
    super.initState();
    _emoji = widget.randomEmoji();
  }

  @override
  Widget build(BuildContext context) {
    return IconButton(
      iconSize: Spacing.x48,
      icon: Text(_emoji, style: const TextStyle(fontSize: Spacing.x48)),
      onPressed: () {
        setState(() {
          _emoji = widget.randomEmoji(filter: _emoji);
        });
      },
    );
  }
}
