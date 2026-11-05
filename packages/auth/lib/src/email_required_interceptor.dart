import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'held_calls.dart';

/// Tells the app that a call was refused with `403 ACCOUNT.EMAIL_REQUIRED`:
/// the account has no address yet. With `emailRequired` that is every call
/// outside the server's allow list; with `emailRequiredToWrite` only a write.
///
/// Nothing is signed out or refreshed. The call waits for [onRequired] (the
/// app opens [EmailRegisterForm] and returns a future, see [HeldCalls.hold]):
/// `true` once the address is confirmed sends the same call again and the
/// caller gets that answer; `false` (the person left) ends it with the
/// original 403. A repeat that is refused again is not held again.
class EmailRequiredInterceptor extends Interceptor {
  EmailRequiredInterceptor({required this.dio, required this.onRequired});

  final Dio dio;
  final Future<bool> Function() onRequired;

  static const _repeatedKey = 'emailRequiredRepeated';

  /// Set once the call was held. A repeat that fails inside another
  /// interceptor (a token refresh) comes back through the chain with this
  /// error; it must not be held a second time.
  static const _heldKey = 'emailRequiredHeld';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 403 ||
        options.extra[_repeatedKey] == true ||
        options.extra[_heldKey] == true ||
        ApiRequestError.fromDioException(err).code !=
            AccountErrorCodes.emailRequired) {
      return handler.next(err);
    }
    options.extra[_heldKey] = true;
    if (!await onRequired()) return handler.next(err);
    try {
      handler.resolve(await sendHeldCallAgain(dio, options, _repeatedKey));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
