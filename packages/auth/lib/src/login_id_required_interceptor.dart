import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';

/// Tells the app that a call was refused with `403 ACCOUNT.LOGIN_ID_REQUIRED`:
/// the account has not chosen its login ID and the server answers nothing
/// outside the ID endpoints until it does (reads included).
///
/// Only reports. The error goes on to the caller as it is: nothing is signed
/// out or refreshed (the session is fine), and the blocked call is NOT sent
/// again. The app shows the ID form ([LoginIdForm]); the screen the person
/// returns to reads its data again.
class LoginIdRequiredInterceptor extends Interceptor {
  LoginIdRequiredInterceptor({required this.onRequired});

  final void Function() onRequired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 &&
        ApiRequestError.fromDioException(err).code ==
            AccountErrorCodes.loginIdRequired) {
      onRequired();
    }
    handler.next(err);
  }
}
