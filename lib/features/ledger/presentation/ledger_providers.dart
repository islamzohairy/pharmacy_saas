import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/data/database_providers.dart';
import '../data/ledger_repository_impl.dart';
import '../domain/ledger_repository.dart';

/// Drift-backed ledger repository — the local database is always the
/// source of truth for reads (ARCHITECTURE.md).
final ledgerRepositoryProvider = Provider<LedgerRepository>(
  (ref) => DriftLedgerRepository(ref.watch(appDatabaseProvider)),
);
