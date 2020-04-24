// Copyright (c) 2012, the Dart project authors.  Please see the AUTHORS file
// for details. All rights reserved. Use of this source code is governed by a
// BSD-style license that can be found in the LICENSE file.

// @dart = 2.6

part of dart.async;

/** Runs user code and takes actions depending on success or failure. */
_runUserCode<T>(
    T userCode(), onSuccess(T value), onError(error, StackTrace stackTrace)) {
  try {
    onSuccess(userCode());
  } catch (e, s) {
    AsyncError replacement = Zone.current.errorCallback(e, s);
    if (replacement == null) {
      onError(e, s);
    } else {
      var error = _nonNullError(replacement.error);
      var stackTrace = replacement.stackTrace;
      onError(error, stackTrace);
    }
  }
}

/** Helper function to cancel a subscription and wait for the potential future,
  before completing with an error. */
void _cancelAndError(StreamSubscription subscription, _Future future, error,
    StackTrace stackTrace) {
  var cancelFuture = subscription.cancel();
  if (cancelFuture != null && !identical(cancelFuture, Future._nullFuture)) {
    cancelFuture.whenComplete(() => future._completeError(error, stackTrace));
  } else {
    future._completeError(error, stackTrace);
  }
}

void _cancelAndErrorWithReplacement(StreamSubscription subscription,
    _Future future, error, StackTrace stackTrace) {
  AsyncError replacement = Zone.current.errorCallback(error, stackTrace);
  if (replacement != null) {
    error = _nonNullError(replacement.error);
    stackTrace = replacement.stackTrace;
  }
  _cancelAndError(subscription, future, error, stackTrace);
}

typedef void _ErrorCallback(error, StackTrace stackTrace);

/** Helper function to make an onError argument to [_runUserCode]. */
_ErrorCallback _cancelAndErrorClosure(
    StreamSubscription subscription, _Future future) {
  return (error, StackTrace stackTrace) {
    _cancelAndError(subscription, future, error, stackTrace);
  };
}

/** Helper function to cancel a subscription and wait for the potential future,
  before completing with a value. */
void _cancelAndValue(StreamSubscription subscription, _Future future, value) {
  var cancelFuture = subscription.cancel();
  if (cancelFuture != null && !identical(cancelFuture, Future._nullFuture)) {
    cancelFuture.whenComplete(() => future._complete(value));
  } else {
    future._complete(value);
  }
}

/**
 * A [Stream] that forwards subscriptions to another stream.
 *
 * This stream implements [Stream], but forwards all subscriptions
 * to an underlying stream, and wraps the returned subscription to
 * modify the events on the way.
 *
 * This class is intended for internal use only.
 */
abstract class _ForwardingStream<S, T> extends Stream<T> {
  final Stream<S> _source;

  _ForwardingStream(this._source);

  bool get isBroadcast => _source.isBroadcast;

  StreamSubscription<T> listen(void onData(T value),
      {Function onError, void onDone(), bool cancelOnError}) {
    cancelOnError = identical(true, cancelOnError);
    return _createSubscription(onData, onError, onDone, cancelOnError);
  }

  StreamSubscription<T> _createSubscription(void onData(T data),
      Function onError, void onDone(), bool cancelOnError) {
    return new _ForwardingStreamSubscription<S, T>(
        this, onData, onError, onDone, cancelOnError);
  }

  // Override the following methods in subclasses to change the behavior.

  void _handleData(S data, _EventSink<T> sink) {
    sink._add(data as Object);
  }

  void _handleError(error, StackTrace stackTrace, _EventSink<T> sink) {
    sink._addError(error, stackTrace);
  }

  void _handleDone(_EventSink<T> sink) {
    sink._close();
  }
}

/**
 * Abstract superclass for subscriptions that forward to other subscriptions.
 */
class _ForwardingStreamSubscription<S, T>
    extends _BufferingStreamSubscription<T> {
  final _ForwardingStream<S, T> _stream;

  StreamSubscription<S> _subscription;

  _ForwardingStreamSubscription(this._stream, void onData(T data),
      Function onError, void onDone(), bool cancelOnError)
      : super(onData, onError, onDone, cancelOnError) {
    _subscription = _stream._source
        .listen(_handleData, onError: _handleError, onDone: _handleDone);
  }

  // _StreamSink interface.
  // Transformers sending more than one event have no way to know if the stream
  // is canceled or closed after the first, so we just ignore remaining events.

  void _add(T data) {
    if (_isClosed) return;
    super._add(data);
  }

  void _addError(Object error, StackTrace stackTrace) {
    if (_isClosed) return;
    super._addError(error, stackTrace);
  }

  // StreamSubscription callbacks.

  void _onPause() {
    if (_subscription == null) return;
    _subscription.pause();
  }

  void _onResume() {
    if (_subscription == null) return;
    _subscription.resume();
  }

  Future _onCancel() {
    if (_subscription != null) {
      StreamSubscription subscription = _subscription;
      _subscription = null;
      return subscription.cancel();
    }
    return null;
  }

  // Methods used as listener on source subscription.

  void _handleData(S data) {
    _stream._handleData(data, this);
  }

  void _handleError(error, StackTrace stackTrace) {
    _stream._handleError(error, stackTrace, this);
  }

  void _handleDone() {
 