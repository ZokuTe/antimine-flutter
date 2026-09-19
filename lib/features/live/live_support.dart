import 'dart:io';

import 'package:flutter/foundation.dart';

/// 直播联动只在桌面端可用（Windows / Linux）。
///
/// Android 不参与：那边要额外处理 INTERNET 权限、后台存活、横屏 overlay，
/// 而直播场景本来就在电脑上跑。web 上 `dart:io` 根本不可用。
///
/// 判断放这里而不是散在各处，是为了让「支不支持」只有一个答案。
bool get isLiveSupported {
  if (kIsWeb) {
    return false;
  }
  return Platform.isWindows || Platform.isLinux;
}
