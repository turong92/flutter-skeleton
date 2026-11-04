import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:skeleton_api_client/testing.dart';
import 'package:skeleton_board/skeleton_board.dart';

import 'fake_board.dart';

/// A scripted board server. Every field can be changed per test; [respond]
/// wins over the defaults when it returns something.
class FakeBoard {
  Map<String, Object?> config = configJson();
  List<List<Map<String, Object?>>> postPages = [
    [postJson(1), postJson(2, mine: true)],
  ];
  Map<String, Object?> detail = postJson(1, body: 'Hello body', mine: false);
  List<Map<String, Object?>> comments = [];
  ResponseBody? Function(RequestOptions options)? respond;
  int nextId = 100;
  /// While set, POSTs wait for it (a slow network).
  Completer<void>? holdPosts;
  late final FakeAdapter adapter = FakeAdapter((o) async {
    if (o.method == 'POST') await holdPosts?.future;
    return _handle(o);
  });

  List<RequestOptions> where(String method, String path) => [
    for (final r in adapter.requests)
      if (r.method == method && r.path == path) r,
  ];

  ResponseBody _handle(RequestOptions o) {
    final custom = respond?.call(o);
    if (custom != null) return custom;
    final path = o.path;
    switch (o.method) {
      case 'GET' when path == '/boards/config':
        return valueBody(config);
      case 'GET' when path == '/boards/general/posts':
        final page = (o.queryParameters['page'] as int?) ?? 0;
        return pageBody(
          postPages[page],
          page: page,
          hasNext: page + 1 < postPages.length,
        );
      case 'GET' when path == '/boards/general/posts/1':
        return valueBody(detail);
      case 'GET' when path == '/boards/general/posts/1/comments':
        return pageBody(comments);
      case 'POST' when path == '/boards/general/posts':
        return valueBody(
          postJson(
            nextId++,
            body: (o.data as Map)['body'] as String,
            title: (o.data as Map)['title'] as String,
            mine: true,
          ),
          status: 201,
        );
      case 'PATCH' when path == '/boards/general/posts/1':
        return valueBody({
          ...detail,
          'title': (o.data as Map)['title'],
          'body': (o.data as Map)['body'],
        });
      case 'DELETE' when path == '/boards/general/posts/1':
        return FakeAdapter.empty(204);
      case 'POST' when path == '/boards/general/posts/1/comments':
        return valueBody(
          commentJson(nextId++, body: (o.data as Map)['body'] as String),
          status: 201,
        );
      case 'PUT' when path.endsWith('/reactions'):
        return valueBody({
          'counts': {(o.data as Map)['type'] as String: 1},
          'myReactions': [(o.data as Map)['type']],
        });
      case 'DELETE' when path.endsWith('/reactions'):
        return valueBody({'counts': <String, int>{}, 'myReactions': <String>[]});
    }
    return errorBody(404, 'COMMON.NOT_FOUND');
  }

  BoardApi get api =>
      BoardApi(clientWith(adapter));
}

/// Mounts [child] with the fake server behind `boardApiProvider`.
Future<ProviderContainer> pumpBoard(
  WidgetTester tester,
  FakeBoard server,
  Widget child, {
  BoardAuthorResolver? resolver,
}) async {
  final container = ProviderContainer(
    overrides: [
      boardApiProvider.overrideWithValue(server.api),
      if (resolver != null)
        boardAuthorResolverProvider.overrideWithValue(resolver),
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}
