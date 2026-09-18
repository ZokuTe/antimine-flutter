import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class ShareImageManager {
  ShareImageManager({Future<Directory>? shareDirectory})
    : shareDirectory = shareDirectory ?? _getShareDirectory();

  final Future<Directory> shareDirectory;

  Future<File?> saveImage(ByteData byteData, String suffix) async {
    final shareFile = await _shareImageOf(suffix);
    // `writeAsBytes` creates the file and truncates it when it already exists,
    // so the explicit exists/delete/create round trip only added syscalls and a
    // window where the target was missing.
    await shareFile.writeAsBytes(byteData.buffer.asUint8List(), flush: true);
    return shareFile;
  }

  Future<File> _shareImageOf(String suffix) async {
    final saveDirectoryPath = (await shareDirectory).path;
    return File('$saveDirectoryPath/antimine-share-$suffix.png');
  }

  static Future<Directory> _getShareDirectory() async {
    final directory = await getApplicationCacheDirectory();
    final shareDirectory = Directory('${directory.path}/antimine');
    if (!await shareDirectory.exists()) {
      await shareDirectory.create();
    }
    return shareDirectory;
  }
}
