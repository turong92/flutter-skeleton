import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:skeleton_iap/skeleton_iap.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import 'support/fakes.dart';

class FakeLauncher extends UrlLauncherPlatform with MockPlatformInterfaceMixin {
  final launched = <({String url, PreferredLaunchMode mode})>[];
  Object? failWith;
  bool result = true;

  @override
  // ignore: type_annotate_public_apis
  get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    if (failWith != null) throw failWith!;
    launched.add((url: url, mode: options.mode));
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late FakeLauncher launcher;
  setUp(() {
    launcher = FakeLauncher();
    UrlLauncherPlatform.instance = launcher;
  });

  test(
    'the web checkout opens in the outside browser, never a web view',
    () async {
      final h = Harness();
      addTearDown(h.dispose);

      await h.service.openWebCheckout();

      expect(launcher.launched.single.url, h.linkUrl);
      expect(
        launcher.launched.single.mode,
        PreferredLaunchMode.externalApplication,
      );
    },
  );

  test(
    'the link and its code are not logged, even when opening fails',
    () async {
      final h = Harness();
      addTearDown(h.dispose);
      launcher.failWith = PlatformException(
        code: 'ACTIVITY_NOT_FOUND',
        message: 'Could not launch ${h.linkUrl}',
      );
      Object? thrown;

      final logs = await capturingLogs(() async {
        try {
          await h.service.openWebCheckout();
        } on Object catch (e) {
          thrown = e;
        }
      });

      expect(thrown, isA<IapWebLinkException>());
      expect('$thrown', isNot(contains('SECRET-CODE')));
      expect('$thrown', isNot(contains('handoff')));
      expect(logs.join('\n'), isNot(contains('SECRET-CODE')));
    },
  );

  test('a link that is not http(s) is not opened', () async {
    final h = Harness(linkUrl: 'intent://evil#Intent;scheme=x;end');
    addTearDown(h.dispose);

    await expectLater(
      h.service.openWebCheckout(),
      throwsA(isA<IapWebLinkException>()),
    );
    expect(launcher.launched, isEmpty);
  });
}
