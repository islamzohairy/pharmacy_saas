// End-to-end live test of the backup path against a real Supabase
// project (plan 03 DoD). Deliberately lives OUTSIDE test/ so CI never
// runs it (no credentials in CI).
//
// ignore_for_file: invalid_use_of_visible_for_testing_member
// (SharedPreferences.setMockInitialValues is @visibleForTesting; the
// analyzer only exempts files under test/, and this one must live in
// test_live/ so CI can't run it without credentials.)
//
// Run (uses the same dart-defines as the app):
//   flutter test test_live/rls_isolation_test.dart \
//     --dart-define=SUPABASE_URL=https://<project>.supabase.co \
//     --dart-define=SUPABASE_ANON_KEY=<anon key>
//
// Prerequisite: supabase/migrations/0001_pharmacy_schema.sql applied, then
// 0002_expense_category.sql (PLANS/10 — must be live before any client
// build sends `expense`). The script self-checks the client contract:
// registration, idempotent push (both whitelisted types — historical
// `cash_draw` and current `expense` with category), tenant isolation
// (each token maps to its own pharmacy), and refusal of unknown tokens /
// invalid categories. Server-side row-level assertions are the SQL test
// in supabase/tests/rls_isolation_test.sql.
//
// Note: anon has no delete grants, so the rows created here stay in the
// project — the SQL gate (supabase/tests/rls_isolation_test.sql, section
// 10) sweeps `live-test-%` tenants at the next gate run; the deploy gate
// runs both, so residue is cleaned as part of the same gate.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  const url = String.fromEnvironment('SUPABASE_URL');
  const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  test('device-token backup path: register, push, isolate, refuse', () async {
    if (url.isEmpty || anonKey.isEmpty) {
      markTestSkipped(
        'SUPABASE_URL/SUPABASE_ANON_KEY not provided; '
        'run with --dart-define.',
      );
      return;
    }

    // supabase_flutter's auth storage sits on shared_preferences, which has
    // no platform channel in `flutter test`; mock it.
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(url: url, publishableKey: anonKey);
    final client = Supabase.instance.client;

    final rand = Random.secure();
    String token() => 'live-test-token-'
        '${List.generate(32, (_) => rand.nextInt(256).toRadixString(16)).join()}';
    String uuid() => 'live-test-'
        '${List.generate(32, (_) => rand.nextInt(256).toRadixString(16)).join()}';

    final tokenA = token();
    final tokenB = token();
    final uuidA = uuid();
    final uuidB = uuid();

    // 1) Registration returns a pharmacy id.
    final pharmacyA = await client.rpc<int>('register_device', params: {
      'p_token': tokenA,
      'p_pharmacy_uuid': uuidA,
      'p_pharmacy_name': 'pharmacy-a',
      'p_currency': 'EGP',
    });
    expect(pharmacyA, isNotNull);

    // 2) First push inserts; identical re-push inserts nothing. Both
    //    whitelisted types are covered: historical `cash_draw` and the
    //    plan-10 `expense` with a category (0002 must be live).
    final entries = [
      {
        'id': 1,
        'type': 'cash_draw',
        'amount_minor': 500,
        'occurred_at': '2026-08-02T10:00:00Z',
        'note': 'draw',
      },
      {
        'id': 2,
        'type': 'expense',
        'amount_minor': 1250,
        'category': 'owner_draw',
        'occurred_at': '2026-08-02T10:05:00Z',
        'note': 'rent',
      },
    ];
    final firstPush = await client.rpc<int>('push_ledger_entries', params: {
      'p_token': tokenA,
      'p_entries': entries,
    });
    expect(firstPush, 2);
    final secondPush = await client.rpc<int>('push_ledger_entries', params: {
      'p_token': tokenA,
      'p_entries': entries,
    });
    expect(secondPush, 0, reason: 'retry must not duplicate rows');

    // 2b) Invalid expense category refused by the server CHECK.
    await expectLater(
      client.rpc<int>('push_ledger_entries', params: {
        'p_token': tokenA,
        'p_entries': [
          {
            'id': 3,
            'type': 'expense',
            'amount_minor': 100,
            'category': 'bogus',
            'occurred_at': '2026-08-02T10:06:00Z',
          },
        ],
      }),
      throwsA(isA<PostgrestException>()),
      reason: 'a category outside the whitelist must be rejected',
    );

    // 3) Tenant isolation: a second device pushes the SAME local id and
    //    gets its own pharmacy; the first tenant's data is untouched by
    //    construction (tenant comes from the token, never the payload).
    final pharmacyB = await client.rpc<int>('register_device', params: {
      'p_token': tokenB,
      'p_pharmacy_uuid': uuidB,
      'p_pharmacy_name': 'pharmacy-b',
      'p_currency': 'EGP',
    });
    expect(pharmacyB, isNot(pharmacyA));
    final pushB = await client.rpc<int>('push_ledger_entries', params: {
      'p_token': tokenB,
      'p_entries': [
        {
          'id': 1,
          'type': 'sale',
          'amount_minor': 99,
          'occurred_at': '2026-08-02T10:10:00Z',
        },
      ],
    });
    expect(pushB, 1);

    // 4) Unknown token refused.
    await expectLater(
      client.rpc<int>('push_ledger_entries', params: {
        'p_token': 'definitely-not-a-real-token',
        'p_entries': entries,
      }),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('unknown device token'),
        ),
      ),
    );

    // 5) Register-first-wins: same uuid, different token refused.
    await expectLater(
      client.rpc<int>('register_device', params: {
        'p_token': token(),
        'p_pharmacy_uuid': uuidA,
        'p_pharmacy_name': 'pharmacy-a',
        'p_currency': 'EGP',
      }),
      throwsA(
        isA<PostgrestException>().having(
          (e) => e.message,
          'message',
          contains('already registered'),
        ),
      ),
    );

    // 6) Real app payload shape (Plan 11-H, mirrors gate section 9): the
    //    app always sends party ids — a sale with product_id + profile_id,
    //    an expense with profile_id + category. Requires 0003 applied;
    //    before it these pushes 409'd with SQLSTATE 23503. This section
    //    asserts the client contract for the exact payload that failed.
    final tokenC = token();
    final uuidC = uuid();
    final pharmacyC = await client.rpc<int>('register_device', params: {
      'p_token': tokenC,
      'p_pharmacy_uuid': uuidC,
      'p_pharmacy_name': 'pharmacy-c',
      'p_currency': 'EGP',
    });
    expect(pharmacyC, isNotNull);

    final realShape = await client.rpc<int>('push_ledger_entries', params: {
      'p_token': tokenC,
      'p_entries': [
        {
          'id': 101,
          'type': 'sale',
          'amount_minor': 1500,
          'product_id': 1,
          'profile_id': 1,
          'occurred_at': '2026-08-05T11:00:00Z',
          'note': 'real-shape sale',
        },
        {
          'id': 102,
          'type': 'expense',
          'amount_minor': 300,
          'profile_id': 1,
          'category': 'rent',
          'occurred_at': '2026-08-05T11:01:00Z',
          'note': 'real-shape expense',
        },
      ],
    });
    expect(
      realShape,
      2,
      reason: 'real app payload with party ids must persist after 0003',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
