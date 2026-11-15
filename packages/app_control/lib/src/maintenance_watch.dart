import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';

/// The code of the backend's maintenance answer (`503 APP_CONTROL.MAINTENANCE`).
const maintenanceErrorCode = 'APP_CONTROL.MAINTENANCE';

/// Is this the maintenance answer? Reads the standard error body.
bool isMaintenanceResponse(Response<dynamic>? response) {
  if (response?.statusCode != 503) return false;
  final body = response?.data;
  return body is Map && body['code'] == maintenanceErrorCode;
}

/// Is this failure the maintenance answer?
bool isMaintenanceError(Object error) {
  if (error is ApiRequestError) {
    return error.apiError.status == 503 &&
        error.apiError.code == maintenanceErrorCode;
  }
  if (error is DioException) return isMaintenanceResponse(error.response);
  return false;
}

/// Calls [onMaintenance] whenever any request of [client] gets the maintenance
/// answer, so the config is read again at once and the maintenance screen
/// shows without waiting for the next start or resume:
/// `installMaintenanceWatch(client, () => ref.read(appConfigProvider.notifier).refresh())`.
/// The config path itself stays open during maintenance, so it never triggers.
void installMaintenanceWatch(ApiClient client, void Function() onMaintenance) {
  client.dio.interceptors.add(
    InterceptorsWrapper(
      onError: (err, handler) {
        if (isMaintenanceError(err)) onMaintenance();
        handler.next(err);
      },
    ),
  );
}
