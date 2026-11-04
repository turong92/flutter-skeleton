import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'models.dart';

/// The backend's code for "a required document has a new version".
const reconsentRequiredCode = 'LEGAL.RECONSENT_REQUIRED';

/// Tells the app that a call was refused with `403 LEGAL.RECONSENT_REQUIRED`
/// and what has to be agreed to.
///
/// Only reports. The error goes on to the caller as it is: nothing is signed
/// out or refreshed (the session is fine), and the blocked call is NOT sent
/// again. The screen the user returns to reads its data again.
class ReconsentInterceptor extends Interceptor {
  ReconsentInterceptor({required this.onRequired});

  final void Function(List<MissingConsent> missing) onRequired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403) {
      final error = ApiRequestError.fromDioException(err);
      if (error.code == reconsentRequiredCode) {
        onRequired(_missingOf(error.apiError.data));
      }
    }
    handler.next(err);
  }

  List<MissingConsent> _missingOf(Object? data) {
    final missing = data is Map ? data['missing'] : null;
    if (missing is! List) return const [];
    return [
      for (final item in missing)
        if (item is Map<String, Object?> && item['type'] is String)
          MissingConsent.fromJson(item),
    ];
  }
}

/// What has to be agreed to before the app can go on; empty = nothing.
class Reconsent extends Notifier<List<MissingConsent>> {
  @override
  List<MissingConsent> build() => const [];

  /// Give this to [ReconsentInterceptor.onRequired]. A 403 without a list
  /// still has to stop the user: the consent screen then reads the list itself.
  void require(List<MissingConsent> missing) => state = missing;

  void clear() => state = const [];
}

final reconsentProvider = NotifierProvider<Reconsent, List<MissingConsent>>(
  Reconsent.new,
);

/// Where the user goes while [missing] is not empty; null = stay.
///
/// - something missing: to [consentPath], with the place they wanted as `from`
/// - nothing missing and on [consentPath]: back to `from`, or [homePath]
///   (`from` must be an app path: starts with `/`, not `//`)
String? reconsentRedirectFor(
  List<MissingConsent> missing,
  Uri location, {
  String consentPath = '/consent',
  String homePath = '/',
}) {
  final onConsent = location.path == consentPath;
  if (missing.isNotEmpty) {
    return onConsent
        ? null
        : '$consentPath?from=${Uri.encodeQueryComponent(location.toString())}';
  }
  if (!onConsent) return null;
  final from = location.queryParameters['from'];
  final inApp = from != null && from.startsWith('/') && !from.startsWith('//');
  return inApp ? from : homePath;
}

/// `GoRouter(redirect: (c, s) => authRedirect(c, s) ?? reconsentRedirect(ref)(c, s))`
GoRouterRedirect reconsentRedirect(
  Ref ref, {
  String consentPath = '/consent',
  String homePath = '/',
}) {
  return (context, routerState) => reconsentRedirectFor(
    ref.read(reconsentProvider),
    routerState.uri,
    consentPath: consentPath,
    homePath: homePath,
  );
}

/// Makes the router re-run its redirect whenever [reconsentProvider] changes.
Listenable reconsentRefreshListenable(Ref ref) {
  final notifier = _Changed();
  ref.listen(reconsentProvider, (_, _) => notifier.changed());
  ref.onDispose(notifier.dispose);
  return notifier;
}

class _Changed extends ChangeNotifier {
  void changed() => notifyListeners();
}
