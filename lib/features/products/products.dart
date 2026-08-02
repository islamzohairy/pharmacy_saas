/// Public API of the products feature.
///
/// Other features import this barrel only — never this feature's internals
/// (no-cross-feature-internal-imports rule, GLOBAL_RULES.md).
library;

export 'data/product_repository_impl.dart';
export 'domain/product.dart';
export 'domain/product_repository.dart';
export 'presentation/products_providers.dart';
