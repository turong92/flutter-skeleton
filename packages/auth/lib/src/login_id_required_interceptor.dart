import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';
import 'held_calls.dart';

/// Tells the app that a call was refused with `403 ACCOUNT.LOGIN_ID_REQUIRED`:
/// the account has not chosen its login ID and the server answers nothing
/// outside the ID endpoints until it does (reads included).
///
/// Nothing is signed out or refreshed (the session is fine). The call waits
/// for [onRequired] (the app shows [LoginIdForm] and returns a future, see
/// [HeldCalls.hold]): `true` once the ID is chosen sends the same call again
/// and the caller gets that answer; `false` (the person left) ends it with the
/// original 403. A repeat that is refused again is not held again.
class LoginIdRequiredInterceptor extends Interceptor {
  LoginIdRequiredInterceptor({required this.dio, required this.onRequired});

  final Dio dio;
  final Future<bool> Function() onRequired;

  static const _repeatedKey = 'loginIdRequiredRepeated';

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.response?.statusCode != 403 ||
        options.extra[_repeatedKey] == true ||
        ApiRequestError.fromDioException(err).code !=
            AccountErrorCodes.loginIdRequired) {
      return handler.next(err);
    }
    if (!await onRequired()) return handler.next(err);
    try {
      handler.resolve(await sendHeldCallAgain(dio, options, _repeatedKey));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
