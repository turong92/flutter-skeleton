# skeleton_social_login_kakao

Kakao sign-in for [`skeleton_social_login`](../social_login/README.md), on `kakao_flutter_sdk_user` 2.x. `KakaoSocialProvider` (server provider id `kakao`) returns the Kakao **access token**; the kotlin-skeleton `auth-social-kakao` module checks it with Kakao (`access_token_info`, its `app_id` must be the configured Kakao app id) and answers with its own session.

| Piece | What it is |
|---|---|
| `KakaoSocialProvider()` | `id` `kakao` · `obtain(nonce)` → `SocialCredential.accessToken` · `signOut()` |

- KakaoTalk installed: signs in through the KakaoTalk app. Not installed, or KakaoTalk failed for a reason other than the person backing out: the Kakao account page. Backing out of the KakaoTalk login is `SocialCancelled` and does **not** open the account page.
- The Kakao SDK takes a nonce only for OIDC ID tokens; this package uses the access token, so `nonce` is ignored.
- `signOut()` calls Kakao's logout and clears the SDK's stored token. No session is not an error.

## Wiring

The app initializes the SDK itself, once, before the first sign-in (the way it initializes Firebase for push); the provider does not.

```dart
import 'package:kakao_flutter_sdk_user/kakao_flutter_sdk_user.dart';

const kakaoNativeAppKey = String.fromEnvironment('KAKAO_NATIVE_APP_KEY');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kakaoNativeAppKey.isNotEmpty) {
    KakaoSdk.init(nativeAppKey: kakaoNativeAppKey);
  }
  runApp(ProviderScope(
    overrides: [
      socialProvidersProvider.overrideWithValue([
        if (kakaoNativeAppKey.isNotEmpty) KakaoSocialProvider(),
      ]),
    ],
    child: const App(),
  ));
}
```

`KAKAO_NATIVE_APP_KEY` (example: `0123456789abcdef0123456789abcdef`, the real one is in Kakao Developers, "Native app key") is kept in an untracked `env/*.json` for `--dart-define-from-file`. Empty means no Kakao button.

## Platform settings (the app's files; not changed by this package)

- Kakao Developers: register the Android package name and key hash, and the iOS bundle id; turn on Kakao Login. The server needs the **App ID** (a number) as `skeleton.auth-social.providers.kakao.app-id`; see kotlin-skeleton `docs/real-provider-setup.md`.
- iOS `Info.plist`: a `CFBundleURLTypes` scheme `kakao<NATIVE_APP_KEY>`; `LSApplicationQueriesSchemes` with `kakaokompassauth` and `kakaolink`. iOS 13 or higher.
- Android: declare `com.kakao.sdk.flutter.auth.AuthCodeHandlerActivity` (the plugin's manifest has it without an intent filter) with an `intent-filter` for `VIEW`, `DEFAULT`, `BROWSABLE` and `<data android:scheme="kakao<NATIVE_APP_KEY>" android:host="oauth"/>`.
- The native key is in two places: the Dart define and the platform files. Keep them the same.

## Button

Shape and logo are the app's. This repo ships no Kakao logo image; follow Kakao's design guide: <https://developers.kakao.com/docs/latest/en/kakaologin/design-guide>.

## Test

`cd packages/social_login_kakao && flutter test`. The SDK calls are replaced by functions (`KakaoSocialProvider.withSdk`); a real KakaoTalk or Kakao account login needs a device and a Kakao app, and is not tested here.
