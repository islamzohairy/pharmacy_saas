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
// Prerequisite: supabase/migrations/0001_pharmacy_schema.sql applied.
// The script self-checks the client contract: registration, idempotent
// push, tenant isolation (each token maps to its own pharmacy), and
// refusal of unknown tokens. Server-side row-level assertions are the
// SQL test in supabase/tests/rls_isolation_test.sql.
//
// Note: anon has no delete grants, so the rows created here stay in the
// project. Run against a throwaway project or accept test tenants.

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

    // 2) First push inserts; identical re-push inserts nothing.
    final entry = {
      'id': 1,
      'type': 'cash_draw',
      'amount_minor': 500,
      'occurred_at': '2026-08-02T10:00:00Z',
      'note': 'draw',
    };
    final firstPush = await client.rpc<int>('push_ledger_entries', params: {
      'p_token': tokenA,
      'p_entries': [entry],
    });
    expect(firstPush, 1);
    final secondPush = await client.rpc<int>('push_ledger_entries', params: {
      'p_token': tokenA,
      'p_entries': [entry],
    });
    expect(secondPush, 0, reason: 'retry must not duplicate rows');

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
        'p_entries': [entry],
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
  }, timeout: const Timeout(Duration(minutes: 2)));
}
