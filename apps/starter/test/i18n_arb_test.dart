// #file i18n
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_i18n/testing.dart';

void main() {
  test('the Korean and English texts have the same keys and placeholders', () {
    expect(
      arbProblems(
        readArb('lib/l10n/app_ko.arb'),
        readArb('lib/l10n/app_en.arb'),
      ),
      isEmpty,
    );
  });
}
