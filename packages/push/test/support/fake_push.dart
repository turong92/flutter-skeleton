import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';

const meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> configJson({
  bool fcm = true,
  List<String> types = const ['COMMENT', 'NEWS'],
}) => {
  'webPush': null,
  'fcm': fcm,
  'types': types,
  'advertisingTypes': <String>[],
};

Map<String, Object?> preferenceJson(
  String type, {
  bool push = true,
  bool allChannelsMuted = false,
}) => {'type': type, 'push': push, 'allChannelsMuted': allChannelsMuted};

Map<String, Object?> deviceJson(String id) => {
  'installationId': id,
  'kind': 'FCM',
  'platform': 'android',
  'label': null,
  'createdAt': '2026-01-01T00:00:00Z',
  'lastSeenAt': '2026-01-01T00:00:00Z',
};

ResponseBody valueBody(Object? value, {int status = 200}) =>
    FakeAdapter.json(status, {'value': value, 'meta': meta});

ResponseBody errorBody(int status, String code) => FakeAdapter.json(status, {
  'code': code,
  'title': 'x',
  'status': status,
});

ApiClient clientWith(FakeAdapter adapter) =>
    ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter);
