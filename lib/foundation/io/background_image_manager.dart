import 'dart:io';

import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// Stores the user's custom background image.
///
/// The picker returns a path inside a cache directory that the OS may clear at
/// any time, so a picked image is copied into the app's support directory. Only
/// the file name is persisted (see [SettingsKeys.backgroundImage]); the full
/// path is resolved on load because the container path can change between
/// installs and OS upgrades.
class BackgroundImageManager {
  BackgroundImageManager({ImagePicker? picker, Future<Directory>? directory})
    : picker = picker ?? ImagePicker(),
      _directory = directory ?? defaultDirectory();

  final ImagePicker picker;
  final Future<Directory> _directory;

  static const String fileNamePrefix = 'background';

  /// Suffix for the file being copied into place. Excluded from cleanup so a
  /// staged copy is never deleted by the replace that owns it.
  static const String stagingSuffix = '.tmp';

  /// The directory that holds the stored background image.
  static Future<Directory> defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/background');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Opens the system image picker and, if the user chose an image, stores a
  /// copy of it. Returns the stored file name, or null if nothing was picked.
  ///
  /// The picker fails when another picker is already active; that is treated as
  /// a cancellation rather than an error.
  Future<String?> pickImage() async {
    final XFile? picked;
    try {
      picked = await picker.pickImage(source: ImageSource.gallery);
    } on PlatformException {
      return null;
    }
    if (picked == null) {
      // Cancelled. The previously stored image must be left untouched.
      return null;
    }

    final directory = await _directory;
    final target = File(
      '${directory.path}/$fileNamePrefix${_extensionOf(picked)}',
    );
    // Copy before deleting anything, so a failed or partial copy cannot leave
    // the user without a background.
    final staged = File('${target.path}$stagingSuffix');
    try {
      await File(picked.path).copy(staged.path);
    } catch (_) {
      if (await staged.exists()) {
        await staged.delete();
      }
      return null;
    }

    // Only one image is kept, so a stale file with a different extension does
    // not linger after the user switches formats.
    await _removeExisting(directory);
    await staged.rename(target.path);
    return _nameOf(target);
  }

  /// Deletes the stored background image, if any.
  Future<void> removeImage() async {
    final directory = await _directory;
    await _removeExisting(directory);
  }

  /// Resolves the on-disk file for a stored background name, or null when it is
  /// unset or the file is gone (e.g. the user cleared app data).
  Future<File?> resolve(String? name) async {
    if (name == null || name.isEmpty) {
      return null;
    }
    final file = File('${(await _directory).path}/$name');
    return await file.exists() ? file : null;
  }

  Future<void> _removeExisting(Directory directory) async {
    if (!await directory.exists()) {
      return;
    }
    await for (final entity in directory.list()) {
      if (entity is! File) {
        continue;
      }
      final name = entity.uri.pathSegments.last;
      // Skip the staged file: it is about to be renamed into place.
      if (name.endsWith(stagingSuffix)) {
        continue;
      }
      if (name.startsWith(fileNamePrefix)) {
        await entity.delete();
      }
    }
  }

  static String _nameOf(File file) => file.uri.pathSegments.last;

  static String _extensionOf(XFile file) {
    final name = file.name;
    final dot = name.lastIndexOf('.');
    if (dot < 0) {
      return '.jpg';
    }
    // Keep only a short, safe extension so it cannot escape the directory.
    final ext = name.substring(dot);
    return RegExp(r'^\.[A-Za-z0-9]{1,5}$').hasMatch(ext) ? ext : '.jpg';
  }
}
