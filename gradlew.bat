// Copyright (c) 2013, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.6

part of dart.convert;

/// The [ByteConversionSink] provides an interface for converters to
/// efficiently transmit byte data.
///
/// Instead of limiting the interface to one non-chunked list of bytes it
/// accepts its input in chunks (themselves being lists of bytes).
///
/// This abstract class will likely get more methods over time. Implementers are
/// urged to extend or mix in [ByteConversionSinkBase] to ensure that their
/// class covers the newly added methods.
abstract class ByteConversionSink extends ChunkedConversionSink<List<int>> {
  ByteConversionSink();
  factory ByteConversionSink.withCallback(
      void callback(List<int> accumulated)) = _ByteCallbackSink;
  factory ByteConversionSink.from(Sink<List<int>> sink) = _ByteAdapterSink;

  /// Adds the next [chunk] to `this`.
  ///
  /// Adds the bytes defined by [start] and [end]-exclusive to `this`.
  ///
  /// If [isLast] is `true` closes `this`.
  ///
  /// Contrary to `add` the given [chunk] must not be held onto. Once the method
  /// returns, it is safe to overwrite the data in it.
  void addSlice(List<int> chunk, int start, int end, bool isLast);

  // TODO(floitsch): add more methods:
  // - iterateBytes.
}

/// This class provides a base-class for converters that need to accept byte
/// inputs.
abstract class ByteConversionSinkBase extends ByteConversionSink {
  void add(List<int> chunk);
  void close();

  void addSlice(List<int> chunk, int start, int end, bool isLast) {
    add(chunk.sublist(start, end));
    if (isLast) close();
  }
}

/// This class adapts a simple [Sink] to a [ByteConversionSink].
///
/// All additional methods of the [ByteConversionSink] (compared to the
/// ChunkedConversionSink) are redirected to the `add` method.
class _ByteAdapterSink extends ByteConversionSinkBase {
  final Sink<List<int>> _sink;

  _ByteAdapterSink(this._sink);

  void add(List<int> chunk) {
    _sink.add(chunk);
  }

  void close() {
    _sink.close();
  }
}

/// This class accumulates all chunks into one list of bytes
///