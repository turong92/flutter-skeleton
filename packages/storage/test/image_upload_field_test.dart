import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

import 'support/fakes.dart';

Future<List<String>> pumpField(
  WidgetTester tester,
  FakeStorage server, {
  List<UploadFile> picks = const [],
  List<String> initial = const [],
  int max = 10,
  StorageFileRules rules = const StorageFileRules(),
}) async {
  var keys = initial;
  late StateSetter rebuild;
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) {
            rebuild = setState;
            return ImageUploadField(
              uploader: server.uploader(rules: rules),
              value: keys,
              max: max,
              pickPhotos: (limit) async => picks.take(limit).toList(),
              labels: const ImageUploadLabels(
                reasons: {'SIZE_TOO_LARGE': 'Too big.'},
              ),
              onChanged: (next) => rebuild(() => keys = next),
            );
          },
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('photo-add')));
  await tester.pumpAndSettle();
  return keys;
}

MemoryUpload photo(String name, [int size = 100]) =>
    MemoryUpload(name, 'image/png', Uint8List(size));

void main() {
  testWidgets(
    'a picked photo is uploaded and its key is handed to the parent',
    (tester) async {
      final server = FakeStorage();
      await pumpField(tester, server, picks: [photo('a.png'), photo('b.png')]);

      final field = tester.widget<ImageUploadField>(
        find.byType(ImageUploadField),
      );
      expect(field.value, ['u/1/a.png', 'u/1/b.png']);
      expect(server.puts, hasLength(2));
      expect(find.byKey(const ValueKey('photo-remove')), findsNWidgets(2));
    },
  );

  testWidgets('removing a photo takes its key out', (tester) async {
    final server = FakeStorage();
    await pumpField(tester, server, picks: [photo('a.png')]);

    await tester.tap(find.byKey(const ValueKey('photo-remove')));
    await tester.pumpAndSettle();

    final field = tester.widget<ImageUploadField>(
      find.byType(ImageUploadField),
    );
    expect(field.value, isEmpty);
  });

  testWidgets('a refused file shows its reason and adds no key', (
    tester,
  ) async {
    final server = FakeStorage();
    await pumpField(
      tester,
      server,
      picks: [photo('big.png', 500)],
      rules: const StorageFileRules(maxSizeBytes: 100),
    );

    expect(find.text('Too big.'), findsOneWidget);
    final field = tester.widget<ImageUploadField>(
      find.byType(ImageUploadField),
    );
    expect(field.value, isEmpty);
    expect(server.puts, isEmpty);
  });

  testWidgets('the parent is told while an upload runs', (tester) async {
    final server = FakeStorage();
    final busy = <bool>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageUploadField(
            uploader: server.uploader(),
            value: const [],
            onChanged: (_) {},
            onBusyChanged: busy.add,
            pickPhotos: (limit) async => [photo('a.png')],
          ),
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('photo-add')));
    await tester.pumpAndSettle();

    expect(busy, [true, false]);
  });

  testWidgets('at the limit the add button is off', (tester) async {
    final server = FakeStorage();
    await pumpField(
      tester,
      server,
      initial: ['u/1/x.png'],
      max: 1,
      picks: [photo('a.png')],
    );

    expect(find.text('No more photos can be added.'), findsOneWidget);
    expect(server.puts, isEmpty);
  });
}
