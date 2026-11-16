import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_storage/skeleton_storage.dart';
import 'package:video_player/video_player.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// A player that plays nothing: it remembers what it was asked and answers the
/// initialization the way the test says.
class _FakePlayer extends VideoPlayerPlatform {
  final calls = <String>[];
  final events = StreamController<VideoEvent>();
  String? lastUrl;

  @override
  Future<void> init() async {}

  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async {
    lastUrl = options.dataSource.uri;
    calls.add('create');
    return 1;
  }

  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => events.stream;

  @override
  Future<void> setLooping(int playerId, bool looping) async =>
      calls.add('looping:$looping');

  @override
  Future<void> setVolume(int playerId, double volume) async =>
      calls.add('volume:$volume');

  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}

  @override
  Future<void> play(int playerId) async => calls.add('play');

  @override
  Future<void> pause(int playerId) async => calls.add('pause');

  @override
  Future<void> dispose(int playerId) async => calls.add('dispose');

  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;

  @override
  Widget buildView(int playerId) => const SizedBox.expand();
}

ImageVariant variant(
  String url, {
  List<ImageAlternate> alternates = const [],
}) => ImageVariant(
  url: url,
  width: 480,
  height: 270,
  contentType: 'image/gif',
  alternates: alternates,
);

const mp4 = ImageAlternate(url: '/files/d.mp4', contentType: 'video/mp4');

Widget host(ImageVariant display, {ImageVariant? thumb}) => MaterialApp(
  home: Scaffold(
    body: StoredAnimatedImage(
      display: display,
      thumb: thumb,
      apiBaseUrl: 'https://api.example.com/api/v1',
    ),
  ),
);

void main() {
  late _FakePlayer player;

  setUp(() {
    player = _FakePlayer();
    VideoPlayerPlatform.instance = player;
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
  });

  tearDown(() {
    // not awaited: close() of a stream nobody listened to never completes
    unawaited(player.events.close());
  });

  void initialized() => player.events.add(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 2),
      size: const Size(480, 270),
    ),
  );

  String drawnPicture(WidgetTester tester) =>
      tester.widget<StoredImage>(find.byType(StoredImage)).url;

  testWidgets('without a video it draws the picture and starts no player', (
    tester,
  ) async {
    await tester.pumpWidget(host(variant('/files/d.gif')));

    expect(drawnPicture(tester), 'https://api.example.com/files/d.gif');
    expect(find.byType(VideoPlayer), findsNothing);
    expect(player.calls, isEmpty);
  });

  testWidgets(
    'with an mp4 it shows the thumb until ready, then plays it silent and looping',
    (tester) async {
      await tester.pumpWidget(
        host(
          variant('/files/d.gif', alternates: [mp4]),
          thumb: variant('/files/t.jpg'),
        ),
      );
      await tester.pump();

      expect(player.lastUrl, 'https://api.example.com/files/d.mp4');
      expect(drawnPicture(tester), 'https://api.example.com/files/t.jpg');
      expect(find.byType(VideoPlayer), findsNothing);

      initialized();
      await tester.pump();
      await tester.pump();

      expect(find.byType(VideoPlayer), findsOneWidget);
      expect(
        player.calls,
        containsAllInOrder(['looping:true', 'volume:0.0', 'play']),
      );
    },
  );

  testWidgets('when the player cannot start it draws the display picture', (
    tester,
  ) async {
    await tester.pumpWidget(host(variant('/files/d.gif', alternates: [mp4])));
    await tester.pump();

    player.events.addError(PlatformException(code: 'VideoError', message: 'x'));
    await tester.pump();
    await tester.pump();

    expect(find.byType(VideoPlayer), findsNothing);
    expect(drawnPicture(tester), 'https://api.example.com/files/d.gif');
  });

  testWidgets('it pauses when it leaves the screen and plays when it is back', (
    tester,
  ) async {
    await tester.pumpWidget(host(variant('/files/d.gif', alternates: [mp4])));
    await tester.pump();
    initialized();
    await tester.pump();
    await tester.pump();
    player.calls.clear();

    final detector = tester.widget<VisibilityDetector>(
      find.byType(VisibilityDetector),
    );
    VisibilityInfo info(Rect bounds) => VisibilityInfo(
      key: detector.key!,
      size: const Size(480, 270),
      visibleBounds: bounds,
    );
    detector.onVisibilityChanged!(info(Rect.zero));
    await tester.pump();
    expect(player.calls, ['pause']);

    detector.onVisibilityChanged!(info(const Rect.fromLTWH(0, 0, 480, 270)));
    await tester.pump();
    expect(player.calls, ['pause', 'play']);
  });
}
