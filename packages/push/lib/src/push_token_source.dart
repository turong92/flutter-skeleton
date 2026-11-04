import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_link.dart';

enum PushPermission { notDetermined, denied, granted }

/// A notification as the app sees it. [link] is already filtered by
/// [safePushLink]: null or an in-app path.
class PushMessage {
  PushMessage({this.title, this.body, Object? link})
    : link = safePushLink(link);

  final String? title;
  final String? body;
  final String? link;
}

/// Where the device token and the incoming notifications come from. The app
/// uses [FirebasePushTokenSource]; tests use `FakePushTokenSource` from
/// `package:skeleton_push/testing.dart`.
abstract interface class PushTokenSource {
  /// False when push cannot work here (Firebase is not initialized).
  bool get available;

  /// `android` or `ios`, as the server's device PUT wants it.
  String get platform;

  Future<PushPermission> permission();

  /// Shows the system permission dialog (once on iOS) and gives the answer.
  Future<PushPermission> requestPermission();

  /// Null when the platform gave none.
  Future<String?> token();

  Stream<String> get onTokenRefresh;

  /// Messages that arrive while the app is in front. Android shows no system
  /// notification then; the app decides what to show.
  Stream<PushMessage> get onMessage;

  /// A notification tapped while the app was running in the background.
  Stream<PushMessage> get onOpened;

  /// The notification whose tap started the app, once.
  Future<PushMessage?> initialMessage();
}

/// `firebase_messaging` behind [PushTokenSource]. It never initializes
/// Firebase: the app does (`Firebase.initializeApp`, see the README), and
/// without that this source is [available] false and every call is empty.
class FirebasePushTokenSource implements PushTokenSource {
  FirebasePushTokenSource();

  FirebaseMessaging get _fcm => FirebaseMessaging.instance;
  bool _presentationSet = false;

  @override
  bool get available => Firebase.apps.isNotEmpty;

  @override
  String get platform =>
      defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';

  @override
  Future<PushPermission> permission() async =>
      _permission(await _fcm.getNotificationSettings());

  @override
  Future<PushPermission> requestPermission() async =>
      _permission(await _fcm.requestPermission());

  @override
  Future<String?> token() async {
    if (!_presentationSet) {
      // iOS shows nothing in front unless asked; Android ignores this.
      _presentationSet = true;
      await _fcm.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );
    }
    // The server sends through the FCM token (HTTP v1 `token`). The newer
    // register()/onRegistered pair gives a Firebase Installation ID for
    // direct send, which the backend does not use, so the token API stays.
    // ignore: deprecated_member_use
    return _fcm.getToken();
  }

  @override
  Stream<String> get onTokenRefresh =>
      // ignore: deprecated_member_use
      available ? _fcm.onTokenRefresh : const Stream.empty();

  @override
  Stream<PushMessage> get onMessage => available
      ? FirebaseMessaging.onMessage.map(_message)
      : const Stream.empty();

  @override
  Stream<PushMessage> get onOpened => available
      ? FirebaseMessaging.onMessageOpenedApp.map(_message)
      : const Stream.empty();

  @override
  Future<PushMessage?> initialMessage() async {
    final message = await _fcm.getInitialMessage();
    return message == null ? null : _message(message);
  }

  static PushPermission _permission(NotificationSettings settings) =>
      switch (settings.authorizationStatus) {
        AuthorizationStatus.authorized ||
        AuthorizationStatus.provisional => PushPermission.granted,
        AuthorizationStatus.denied ||
        AuthorizationStatus.deniedPermanently => PushPermission.denied,
        AuthorizationStatus.notDetermined => PushPermission.notDetermined,
      };

  static PushMessage _message(RemoteMessage message) => PushMessage(
    title: message.notification?.title,
    body: message.notification?.body,
    link: message.data['link'],
  );
}
