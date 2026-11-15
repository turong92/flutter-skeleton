import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_storage/skeleton_storage.dart';

List<String> _networkUrls(WidgetTester t) => [
  for (final i in t.widgetList<Image>(find.byType(Image)))
    if (i.image is NetworkImage) (i.image as NetworkImage).url,
];

void main() {
  testWidgets('keeps the picture drawn while a new signed address loads, '
      'then swaps', (t) async {
    final next = Completer<ImageInfo>();
    imageCache.clear();
    addTearDown(imageCache.clear);
    imageCache.putIfAbsent(
      const NetworkImage('https://cdn.example.com/new'),
      () => OneFrameImageStreamCompleter(next.future),
    );
    Future<void> show(String url) =>
        t.pumpWidget(MaterialApp(home: HeldImage(url: url)));

    await show('https://cdn.example.com/old');
    expect(_networkUrls(t), ['https://cdn.example.com/old']);

    await show('https://cdn.example.com/new');
    await t.pump();
    expect(_networkUrls(t), [
      'https://cdn.example.com/old',
    ], reason: 'the new one is not there yet');

    final image = await t.runAsync(() => createTestImage(width: 1, height: 1));
    next.complete(ImageInfo(image: image!));
    await t.runAsync(() => Future<void>.delayed(Duration.zero));
    await t.pump();
    expect(_networkUrls(t), ['https://cdn.example.com/new']);
  });

  testWidgets('hands its size and label on to the picture', (t) async {
    await t.pumpWidget(
      const MaterialApp(
        home: HeldImage(
          url: 'https://cdn.example.com/a',
          width: 4,
          height: 3,
          semanticLabel: 'a walk',
        ),
      ),
    );
    final ratio = t.widget<AspectRatio>(find.byType(AspectRatio));
    expect(ratio.aspectRatio, closeTo(4 / 3, 0.001));
    expect(t.widget<Image>(find.byType(Image)).semanticLabel, 'a walk');
  });
}
