import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:skeleton_auth/skeleton_auth.dart';

// #if iap
import 'screens/store_screen.dart';
// #endif
// #if social-login
import 'social_support.dart';

// #endif

/// Everything one person's data sits in. When the session ends (or begins, or
/// one account is swapped for another) these are dropped, so the next person
/// on this phone never sees it. A new public provider in `lib/` goes here or
/// into [sessionScopeExempt]; `test/session_scope_test.dart` fails until it
/// does.
final userScopedProviders = <String, ProviderOrFamily>{
  // 'myDataProvider': myDataProvider,
  // #if social-login
  'linkedMethodsProvider': linkedMethodsProvider,
  // #endif
  // #if iap
  'mySubscriptionProvider': mySubscriptionProvider,
  // #endif
};

/// Providers that hold no one's data, and why (the reason is required).
const sessionScopeExempt = <String, String>{
  'routerProvider': 'navigation only; it follows the session itself',
  // #if notifications realtime
  'inboxRealtimeProvider': 'holds nothing; the stream is open only signed in',
  // #endif
};

/// Watched once at the app root.
final sessionResetProvider = sessionResetOf(userScopedProviders);
