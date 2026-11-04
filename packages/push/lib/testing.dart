/// Test double for apps that test against `push`: import it from tests only
/// (`package:skeleton_push/testing.dart`).
library;

import 'dart:async';

import 'package:skeleton_push/skeleton_push.dart';

class FakePushTokenSource implements PushTokenSource {
  FakePushTokenSource({
    this.available = true,
    this.permissionState = PushPermission.notDetermined,
    PushPermission? permission,
    this.requestResult = PushPermission.granted,
    this.tokenValue = 'fake-token',
    String? token,
    this.initial,
    this.platform = 'android',
  }) {
    if (permission != null) permissionState = permission;
    if (token != null) tokenValue = token;
  }

  @override
  final bool available;
  @override
  final String platform;

  PushPermission permissionState;

  /// What the system dialog answers.
  PushPermission requestResult;
  String? tokenValue;
  PushMessage? initial;

  /// How many times the system dialog was asked for.
  int permissionRequests = 0;

  final _refresh = StreamController<String>.broadcast();
  final _foreground = StreamController<PushMessage>.broadcast();
  final _opened = StreamController<PushMessage>.broadcast();

  void refreshToken(String token) {
    tokenValue = token;
    _refresh.add(token);
  }

  /// A message arrives while the app is in front.
  void receive(PushMessage message) => _foreground.add(message);

  /// A notification is tapped while the app runs in the background.
  void tap(PushMessage message) => _opened.add(message);

  @override
  Future<PushPermission> permission() async => permissionState;

  @override
  Future<PushPermission> requestPermission() async {
    permissionRequests++;
    permissionState = requestResult;
    return requestResult;
  }

  @override
  Future<String?> token() async => tokenValue;

  @override
  Stream<String> get onTokenRefresh => _refresh.stream;

  @override
  Stream<PushMessage> get onMessage => _foreground.stream;

  @override
  Stream<PushMessage> get onOpened => _opened.stream;

  @override
  Future<PushMessage?> initialMessage() async => initial;
}
