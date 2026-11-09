import 'package:flutter_test/flutter_test.dart';

import 'support_ko_labels.dart';

void main() {
  test('every Korean set names every field of its Labels class', () {
    expect(koLabelProblems('lib/src', requireAll: true), isEmpty);
  });
}
