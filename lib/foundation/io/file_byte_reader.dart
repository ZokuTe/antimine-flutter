import 'dart:typed_data';

/// Reads big-endian primitives from a fixed byte buffer.
///
/// The format is big-endian, so every accessor passes [Endian.big]; the
/// default on the host is little-endian. `ByteData` reads a field in one step,
/// where folding over a byte range allocated an iterator per field.
class FileByteReader {
  FileByteReader(this.bytes) : _data = ByteData.sublistView(bytes);

  final Uint8List bytes;
  final ByteData _data;
  int _index = 0;

  bool eof() {
    return _index >= bytes.length;
  }

  bool readBool() {
    return readInt() != 0;
  }

  int readInt() {
    final current = _index;
    _index += _intSize;
    return _data.getInt32(current, Endian.big);
  }

  int readLong() {
    final current = _index;
    _index += _longSize;
    return _data.getInt64(current, Endian.big);
  }

  static const _intSize = 4;
  static const _longSize = 8;
}
