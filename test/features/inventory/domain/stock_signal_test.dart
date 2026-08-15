import 'package:flutter_test/flutter_test.dart';

import 'package:pharmacy_saas/features/inventory/domain/stock_signal.dart';

/// The full D14 signal matrix (PLANS/14 §5.2, §7): untracked never
/// signals; out-of-stock covers zero and negative on-hand; low requires
/// a set threshold and positive stock at or below it; no widget computes
/// signal state — this pure domain function is the single derivation.
void main() {
  group('stockSignal', () {
    test('untracked product (null on-hand) never signals', () {
      expect(stockSignal(onHand: null, threshold: 5), StockSignal.none);
      expect(stockSignal(onHand: null, threshold: null), StockSignal.none);
    });

    test('tracked with zero on-hand is out of stock', () {
      expect(stockSignal(onHand: 0, threshold: 10), StockSignal.outOfStock);
      expect(stockSignal(onHand: 0, threshold: null), StockSignal.outOfStock);
    });

    test('tracked with negative on-hand is out of stock, never clamped or '
        'hidden (D3 lineage)', () {
      expect(stockSignal(onHand: -3, threshold: 10), StockSignal.outOfStock);
      expect(stockSignal(onHand: -3, threshold: null), StockSignal.outOfStock);
    });

    test('positive on-hand below a set threshold is low', () {
      expect(stockSignal(onHand: 3, threshold: 5), StockSignal.low);
    });

    test('positive on-hand above the threshold is none', () {
      expect(stockSignal(onHand: 6, threshold: 5), StockSignal.none);
    });

    test('threshold unset with small positive quantity is none '
        '(out-of-stock signal only — D14)', () {
      expect(stockSignal(onHand: 1, threshold: null), StockSignal.none);
    });

    test('on-hand exactly at the threshold boundary is low', () {
      expect(stockSignal(onHand: 5, threshold: 5), StockSignal.low);
    });

    test('threshold 0 adds nothing beyond the out-of-stock signal', () {
      expect(stockSignal(onHand: 3, threshold: 0), StockSignal.none);
      expect(stockSignal(onHand: 0, threshold: 0), StockSignal.outOfStock);
    });
  });
}