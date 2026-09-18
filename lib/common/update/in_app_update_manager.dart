import 'dart:io';

import 'package:in_app_update/in_app_update.dart';

class InAppUpdateManager {
  AppUpdateInfo? _updateInfo;

  void init() async {
    if (!Platform.isAndroid) {
      return;
    }

    try {
      _updateInfo = await InAppUpdate.checkForUpdate();
    } catch (e) {
      _updateInfo = null;
    }
  }

  void checkForUpdate() async {
    if (_updateInfo == null) {
      return;
    }

    if (_updateInfo?.updateAvailability == UpdateAvailability.updateAvailable) {
      await InAppUpdate.startFlexibleUpdate();
    }
  }

  void dispose() {
    _updateInfo = null;
  }
}
