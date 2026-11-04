import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models.dart';
import 'payment_api.dart';

/// The app overrides this with the one `ApiClient` it uses for everything:
/// `paymentApiProvider.overrideWith((ref) => PaymentApi(ref.watch(apiClientProvider)))`.
final paymentApiProvider = Provider<PaymentApi>(
  (ref) => throw UnimplementedError(
    'Override paymentApiProvider with a PaymentApi built on the app\'s ApiClient',
  ),
);

final paymentConfigProvider = FutureProvider<PaymentConfig>(
  (ref) => ref.watch(paymentApiProvider).config(),
  retry: (_, _) => null,
);
