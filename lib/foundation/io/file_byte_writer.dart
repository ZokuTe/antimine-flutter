import 'dart:typed_data';

/// Writes big-endian primitives into a growable buffer.
///
/// The format is big-endian; the host default is little-endian, so every setter
/// passes [Endian.big] explicitly. Records are staged into an 8-byte scratch
/// buffer and appended, which keeps a save of any size to one allocation of
/// backing storage instead of one list per field.
class FileByteWriter {
  /// [copy] must stay true: records are staged into [_scratch] and would
  /// otherwise share one buffer, leaving every chunk holding the last value
  /// written.
  final BytesBuilder _builder = BytesBuilder(copy: true);
  final ByteData _scratch = ByteData(_longSize);

  Uint8List get bytes => _builder.toBytes();

  void clear() {
    _builder.clear();
  }

  void writeInt(int value) {
    _scratch.setInt32(0, value, Endian.big);
    _builder.add(_scratch.buffer.asUint8List(0, _intSize));
  }

  void writeLong(int value) {
    _scratch.setInt64(0, value, Endian.big);
    _builder.add(_scratch.buffer.asUint8List(0, _longSize));
  }

  /// Bools are stored as a four-byte 0/1, which is what the reader expects.
  void writeBool(bool value) {
    writeInt(value ? 1 : 0);
  }

  static const _intSize = 4;
  static const _longSize = 8;
}
