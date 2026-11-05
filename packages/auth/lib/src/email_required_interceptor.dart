import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

import 'account_models.dart';

/// Tells the app that a call was refused with `403 ACCOUNT.EMAIL_REQUIRED`:
/// the account has no address yet. With `emailRequired` that is every call
/// outside the server's allow list; with `emailRequiredToWrite` only a write.
///
/// Only reports. The error goes on to the caller as it is: nothing is signed
/// out or refreshed, and the blocked call is NOT sent again (the person does
/// the action again once the address is confirmed). The app shows
/// [EmailRegisterForm].
class EmailRequiredInterceptor extends Interceptor {
  EmailRequiredInterceptor({required this.onRequired});

  final void Function() onRequired;

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 403 &&
        ApiRequestError.fromDioException(err).code ==
            AccountErrorCodes.emailRequired) {
      onRequired();
    }
    handler.next(err);
  }
}
