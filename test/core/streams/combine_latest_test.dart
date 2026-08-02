import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/core/streams/combine_latest.dart';

void main() {
  group('combineLatest3', () {
    test('emits nothing until all three inputs have emitted', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final emissions = <(int, int, int)>[];

      final subscription = combineLatest3(
        a.stream,
        b.stream,
        c.stream,
      ).listen(emissions.add);

      a.add(1);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, isEmpty);

      b.add(2);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, isEmpty);

      c.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, [(1, 2, 3)]);

      await subscription.cancel();
      await a.close();
      await b.close();
      await c.close();
    });

    test('re-emits the latest tuple when a later input changes', () async {
      final a = StreamController<int>();
      final b = StreamController<int>();
      final c = StreamController<int>();
      final emissions = <(int, int, int)>[];

      final subscription = combineLatest3(
        a.stream,
        b.stream,
        c.stream,
      ).listen(emissions.add);

      a.add(1);
      b.add(2);
      c.add(3);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, [(1, 2, 3)]);

      b.add(20);
      await Future<void>.delayed(Duration.zero);
      expect(emissions, [(1, 2, 3), (1, 20, 3)]);

      await subscription.cancel();
      await a.close();
      await b.close();
      await c.close();
    });

    test('canceling the output cancels the input subscriptions', () async {
      var canceled = false;
      final a = StreamController<int>.broadcast(
        onCancel: () => canceled = true,
      );
      final b = StreamController<int>();
      final c = StreamController<int>();

      final subscription = combineLatest3(
        a.stream,
        b.stream,
        c.stream,
      ).listen((_) {});

      a.add(1);
      b.add(2);
      c.add(3);
      await Future<void>.delayed(Duration.zero);

      await subscription.cancel();
      expect(canceled, isTrue);

      await a.close();
      await b.close();
      await c.close();
    });
  });
}
