import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_app_control/skeleton_app_control.dart';

void main() {
  group('isVersionBelow compares numbers part by part', () {
    test('1.10 is newer than 1.9 although the text sorts the other way', () {
      expect('1.10'.compareTo('1.9'), lessThan(0));
      expect(isVersionBelow('1.9', '1.10'), isTrue);
      expect(isVersionBelow('1.10', '1.9'), isFalse);
      expect(isVersionBelow('1.9.12', '1.10.0'), isTrue);
    });

    test('missing trailing parts count as zero and equal is not below', () {
      expect(isVersionBelow('1.2', '1.2.0'), isFalse);
      expect(isVersionBelow('1.2.0', '1.2'), isFalse);
      expect(isVersionBelow('2', '2.0.0.0'), isFalse);
      expect(isVersionBelow('1.2', '1.2.1'), isTrue);
    });

    test(
      'a build number or a pre-release suffix on the app version is ignored',
      () {
        expect(AppVersion.parse('1.2.3+45')?.parts, [1, 2, 3]);
        expect(AppVersion.parse('2.0.0-beta.1')?.parts, [2, 0, 0]);
        expect(isVersionBelow('1.9.0+7', '1.10'), isTrue);
      },
    );

    test('what cannot be read never forces an update', () {
      for (final bad in ['', 'dev', '1..2', '1.2.3.4.5', 'a.b']) {
        expect(AppVersion.parse(bad), isNull, reason: bad);
      }
      expect(isVersionBelow('dev', '2.0'), isFalse);
      expect(isVersionBelow('1.0', 'soon'), isFalse);
    });
  });
}
