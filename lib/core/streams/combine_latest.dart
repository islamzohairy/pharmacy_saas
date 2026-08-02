import 'dart:async';

/// Emits the latest value of [first], [second] and [third] whenever any of
/// them emits, once all three have emitted at least once (combineLatest
/// semantics).
///
/// The first emission happens only after every input has produced a value —
/// before that the output stays silent. Subscriptions to the input streams
/// are canceled when the returned stream is canceled, so callers may hand
/// the result to a Riverpod provider without leaking drift query listeners.
Stream<(A, B, C)> combineLatest3<A, B, C>(
  Stream<A> first,
  Stream<B> second,
  Stream<C> third,
) {
  final subscriptions = <StreamSubscription<dynamic>>[];
  late final StreamController<(A, B, C)> controller;
  controller = StreamController<(A, B, C)>(
    onCancel: () async {
      for (final subscription in subscriptions) {
        await subscription.cancel();
      }
    },
  );

  A? firstValue;
  B? secondValue;
  C? thirdValue;
  var firstReady = false;
  var secondReady = false;
  var thirdReady = false;

  void emitIfReady() {
    if (firstReady && secondReady && thirdReady) {
      controller.add((firstValue!, secondValue!, thirdValue!));
    }
  }

  subscriptions
    ..add(
      first.listen((value) {
        firstValue = value;
        firstReady = true;
        emitIfReady();
      }, onError: controller.addError),
    )
    ..add(
      second.listen((value) {
        secondValue = value;
        secondReady = true;
        emitIfReady();
      }, onError: controller.addError),
    )
    ..add(
      third.listen((value) {
        thirdValue = value;
        thirdReady = true;
        emitIfReady();
      }, onError: controller.addError),
    );

  return controller.stream;
}
