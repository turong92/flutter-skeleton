import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_audio/skeleton_audio.dart';
import 'package:skeleton_audio/testing.dart';

void main() {
  late MemoryAudioSettingsStore store;

  Future<ProviderContainer> pumpSection(
    WidgetTester tester, {
    AudioSettings settings = const AudioSettings(),
    AudioLabels labels = const AudioLabels(),
  }) async {
    store = MemoryAudioSettingsStore();
    final container = ProviderContainer(
      overrides: [
        audioSettingsStoreProvider.overrideWithValue(store),
        savedAudioSettingsProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(body: AudioSettingsSection(labels: labels)),
        ),
      ),
    );
    return container;
  }

  testWidgets('a switch and a slider for each of music and effects', (
    tester,
  ) async {
    await pumpSection(tester);

    expect(find.text('Background music'), findsOneWidget);
    expect(find.text('Sound effects'), findsOneWidget);
    expect(find.byType(Switch), findsNWidgets(2));
    expect(find.byType(Slider), findsNWidgets(2));
  });

  testWidgets('the switch changes the setting and keeps it', (tester) async {
    final container = await pumpSection(tester);

    await tester.tap(find.byType(Switch).first);
    await tester.pump();

    expect(container.read(audioSettingsProvider).bgmEnabled, isFalse);
    expect(store.saved?.bgmEnabled, isFalse);
    expect(container.read(audioSettingsProvider).sfxEnabled, isTrue);
  });

  testWidgets('the slider sets the volume of its own sound', (tester) async {
    final container = await pumpSection(tester);

    final slider = tester.widgetList<Slider>(find.byType(Slider)).last;
    slider.onChanged!(0.3);
    await tester.pump();

    // heard at once, written when the finger leaves the slider
    expect(container.read(audioSettingsProvider).sfxVolume, 0.3);
    expect(container.read(audioSettingsProvider).bgmVolume, 1.0);
    expect(store.saved, isNull);

    slider.onChangeEnd!(0.3);
    await tester.pump();
    expect(store.saved?.sfxVolume, 0.3);
  });

  testWidgets('a sound that is switched off has its slider disabled', (
    tester,
  ) async {
    await pumpSection(tester, settings: const AudioSettings(bgmEnabled: false));

    final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
    expect(sliders.first.onChanged, isNull);
    expect(sliders.last.onChanged, isNotNull);
  });

  testWidgets('the Korean labels', (tester) async {
    await pumpSection(tester, labels: const AudioLabels.ko());

    expect(find.text('배경음'), findsOneWidget);
    expect(find.text('효과음'), findsOneWidget);
  });
}
