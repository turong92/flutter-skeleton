/// What the checkout window sent back through its return address.
sealed class CheckoutReturn {
  const CheckoutReturn();
}

/// The `successUrl` was reached: the values are the buyer's side of the story
/// and still have to match the order (see `purchase()`).
class CheckoutSucceeded extends CheckoutReturn {
  const CheckoutSucceeded({
    required this.paymentKey,
    required this.orderId,
    required this.amount,
  });

  final String paymentKey;
  final String orderId;
  final int amount;
}

/// The `failUrl` was reached (the provider's `code`, e.g.
/// `PAY_PROCESS_CANCELED`), or the success address was not usable
/// (`INVALID_RETURN`).
class CheckoutFailed extends CheckoutReturn {
  const CheckoutFailed({required this.code, this.orderId});

  final String code;
  final String? orderId;
}

/// What to do with an address the checkout window is about to open.
sealed class CheckoutNavigation {
  const CheckoutNavigation();
}

/// Let the window load it.
class NavigationLoad extends CheckoutNavigation {
  const NavigationLoad();
}

/// A return address: do not load it, hand [result] over.
class NavigationReturn extends CheckoutNavigation {
  const NavigationReturn(this.result);

  final CheckoutReturn result;
}

/// `intent://`: open [launch] and go to its market address when no app answers.
class NavigationOpenIntent extends CheckoutNavigation {
  const NavigationOpenIntent(this.launch);

  final IntentLaunch launch;
}

/// `market://` or an app scheme: hand it to the system.
class NavigationOpenExternal extends CheckoutNavigation {
  const NavigationOpenExternal(this.uri);

  final Uri uri;
}

/// Do nothing with it.
class NavigationBlock extends CheckoutNavigation {
  const NavigationBlock();
}

/// An Android `intent://` address turned into what a plain launcher can open.
class IntentLaunch {
  const IntentLaunch({required this.appUri, this.marketUri});

  /// `<scheme>://<rest>`.
  final Uri appUri;

  /// `market://details?id=<package>`, when the intent names a package.
  final Uri? marketUri;
}

final _schemePattern = RegExp(r'^[A-Za-z][A-Za-z0-9+.\-]*$');
final _packagePattern = RegExp(r'^[A-Za-z0-9_.]+$');

// Schemes an intent must not turn into: they are the window's own business or
// reach local data.
const _notForIntents = {
  'http',
  'https',
  'file',
  'content',
  'javascript',
  'intent',
  'data',
  'about',
  'blob',
};

// Loaded by the window itself.
const _inWindow = {'http', 'https', 'about', 'data', 'blob', 'javascript'};

/// Reads an Android `intent://<body>#Intent;scheme=<s>;package=<p>;...;end`
/// address. Null when it has no usable scheme. Everything else in the intent
/// (component, extras, fallback address) is dropped on purpose: only the app
/// scheme and the store address are ever opened.
IntentLaunch? intentToLaunch(String intentUrl) {
  const prefix = 'intent://';
  if (!intentUrl.startsWith(prefix)) return null;
  final marker = intentUrl.indexOf('#Intent;');
  if (marker < 0) return null;
  final body = intentUrl.substring(prefix.length, marker);
  String? scheme;
  String? package;
  for (final part
      in intentUrl.substring(marker + '#Intent;'.length).split(';')) {
    if (part.startsWith('scheme=')) scheme = part.substring(7);
    if (part.startsWith('package=')) package = part.substring(8);
  }
  if (scheme == null ||
      !_schemePattern.hasMatch(scheme) ||
      _notForIntents.contains(scheme.toLowerCase())) {
    return null;
  }
  final appUri = Uri.tryParse('$scheme://$body');
  if (appUri == null) return null;
  return IntentLaunch(
    appUri: appUri,
    marketUri: package != null && _packagePattern.hasMatch(package)
        ? Uri.parse('market://details?id=$package')
        : null,
  );
}

/// Decides what the checkout window does with [url] before it loads it.
///
/// [successUrl] and [failUrl] are addresses that are never really opened: the
/// window is stopped on the way there and the values are read off the address.
/// They match by scheme, host, port and path only; the query is the provider's.
CheckoutNavigation classifyCheckoutNavigation(
  String url, {
  required Uri successUrl,
  required Uri failUrl,
}) {
  final uri = Uri.tryParse(url);
  if (uri == null) return const NavigationBlock();
  if (_sameAddress(uri, successUrl)) {
    return NavigationReturn(_readSuccess(uri));
  }
  if (_sameAddress(uri, failUrl)) {
    return NavigationReturn(
      CheckoutFailed(
        code: uri.queryParameters['code'] ?? 'UNKNOWN',
        orderId: uri.queryParameters['orderId'],
      ),
    );
  }
  final scheme = uri.scheme.toLowerCase();
  if (_inWindow.contains(scheme)) return const NavigationLoad();
  if (scheme == 'intent') {
    final launch = intentToLaunch(url);
    return launch == null
        ? const NavigationBlock()
        : NavigationOpenIntent(launch);
  }
  if (scheme == 'file' || scheme == 'content' || scheme.isEmpty) {
    return const NavigationBlock();
  }
  return NavigationOpenExternal(uri);
}

bool _sameAddress(Uri a, Uri b) =>
    a.scheme.toLowerCase() == b.scheme.toLowerCase() &&
    a.host.toLowerCase() == b.host.toLowerCase() &&
    a.port == b.port &&
    a.path == b.path;

CheckoutReturn _readSuccess(Uri uri) {
  final query = uri.queryParameters;
  final paymentKey = query['paymentKey'];
  final orderId = query['orderId'];
  final amount = query['amount'];
  if (paymentKey == null ||
      paymentKey.isEmpty ||
      orderId == null ||
      orderId.isEmpty ||
      amount == null ||
      !RegExp(r'^\d+$').hasMatch(amount)) {
    return CheckoutFailed(code: 'INVALID_RETURN', orderId: orderId);
  }
  return CheckoutSucceeded(
    paymentKey: paymentKey,
    orderId: orderId,
    amount: int.parse(amount),
  );
}
