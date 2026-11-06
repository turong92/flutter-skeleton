// #file push
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

/// The Firebase options from the dart-define values of this platform, or null
/// when they are not all there (then Firebase is not started at all).
FirebaseOptions? firebaseOptionsFor(TargetPlatform platform) {
  final appId = switch (platform) {
    TargetPlatform.android => AppConfig.firebaseAndroidAppId,
    TargetPlatform.iOS => AppConfig.firebaseIosAppId,
    _ => '',
  };
  if (appId.isEmpty ||
      AppConfig.firebaseApiKey.isEmpty ||
      AppConfig.firebaseProjectId.isEmpty ||
      AppConfig.firebaseMessagingSenderId.isEmpty) {
    return null;
  }
  return FirebaseOptions(
    apiKey: AppConfig.firebaseApiKey,
    appId: appId,
    messagingSenderId: AppConfig.firebaseMessagingSenderId,
    projectId: AppConfig.firebaseProjectId,
  );
}

/// Starts Firebase when this build has its values. Never throws: a broken
/// value leaves push `unavailable` and the rest of the app untouched.
Future<void> initFirebaseIfConfigured() async {
  final options = firebaseOptionsFor(defaultTargetPlatform);
  if (options == null) return;
  try {
    await Firebase.initializeApp(options: options);
  } catch (e) {
    debugPrint('Firebase did not start, push is off: ${e.runtimeType}');
  }
}
