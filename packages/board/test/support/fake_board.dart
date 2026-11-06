import 'package:dio/dio.dart';
import 'package:skeleton_api_client/skeleton_api_client.dart';
import 'package:skeleton_api_client/testing.dart';

const meta = {'timestamp': '2026-01-01T00:00:00Z'};

Map<String, Object?> configJson({
  int maxCommentDepth = 2,
  int titleMaxLength = 40,
  int bodyMaxLength = 200,
  int commentMaxLength = 100,
  bool authorRequired = false,
  List<String> reactionTypes = const ['LIKE', 'DISLIKE'],
}) => {
  'reactionTypes': reactionTypes,
  'reactionMode': 'SINGLE',
  'maxCommentDepth': maxCommentDepth,
  'titleMaxLength': titleMaxLength,
  'bodyMaxLength': bodyMaxLength,
  'commentMaxLength': commentMaxLength,
  'maxPageSize': 50,
  'canModerate': false,
  'authorRequired': authorRequired,
  'guestEnabled': true,
  'guestSecret': 'PASSWORD',
  'guestNameMaxLength': 20,
  'captchaRequired': false,
  'commentMaxAttachments': 0,
};

Map<String, Object?> postJson(
  int id, {
  String title = 'Title',
  String? body,
  bool mine = false,
  Map<String, int> reactionCounts = const {},
  List<String> myReactions = const [],
  int commentCount = 0,
  List<String> attachments = const [],
  Map<String, String>? attachmentUrls,
  Map<String, Object?>? attachmentImages,
  List<String>? attachmentsPending,
}) => {
  'attachments': attachments,
  'attachmentUrls': ?attachmentUrls,
  'attachmentImages': ?attachmentImages,
  'attachmentsPending': ?attachmentsPending,
  'id': id,
  'boardCode': 'general',
  'authorId': 'acc_other',
  'title': title,
  'excerpt': 'excerpt $id',
  'body': ?body,
  'status': 'PUBLISHED',
  'pinned': false,
  'viewCount': 3,
  'commentCount': commentCount,
  'reactionCounts': reactionCounts,
  'myReactions': myReactions,
  'attachmentCount': 0,
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
  'authorDeleted': false,
  'authorName': 'Alice',
  'authorTag': '0001',
  'mine': mine,
  'authorGuest': false,
};

Map<String, Object?> commentJson(
  int id, {
  String? body = 'comment',
  int depth = 0,
  int? parentId,
  int? rootId,
  String status = 'PUBLISHED',
  bool mine = false,
  List<Map<String, Object?>>? replies,
  Map<String, int> reactionCounts = const {},
  List<String> myReactions = const [],
}) => {
  'id': id,
  'postId': 1,
  'parentId': parentId,
  'rootId': rootId ?? id,
  'depth': depth,
  'authorId': 'acc_other',
  'body': body,
  'status': status,
  'reactionCounts': reactionCounts,
  'myReactions': myReactions,
  'replyCount': replies?.length ?? 0,
  'createdAt': '2026-01-01T00:00:00Z',
  'updatedAt': '2026-01-01T00:00:00Z',
  'replies': ?replies,
  'authorDeleted': false,
  'authorName': 'Bob',
  'authorTag': null,
  'mine': mine,
  'authorGuest': false,
};

Map<String, Object?> paginationJson({
  int page = 0,
  int size = 20,
  int total = 1,
  bool hasNext = false,
}) => {
  'page': page,
  'size': size,
  'totalElements': total,
  'totalPages': hasNext ? page + 2 : page + 1,
  'hasNext': hasNext,
  'hasPrevious': page > 0,
};

ResponseBody pageBody(
  List<Map<String, Object?>> values, {
  int page = 0,
  bool hasNext = false,
}) => FakeAdapter.json(200, {
  'values': values,
  'pagination': paginationJson(
    page: page,
    total: values.length,
    hasNext: hasNext,
  ),
  'meta': meta,
});

ResponseBody valueBody(Map<String, Object?> value, {int status = 200}) =>
    FakeAdapter.json(status, {'value': value, 'meta': meta});

ResponseBody errorBody(int status, String code, {Object? data}) =>
    FakeAdapter.json(status, {
      'code': code,
      'title': 'x',
      'status': status,
      'data': ?data,
    });

ApiClient clientWith(FakeAdapter adapter) =>
    ApiClient(baseUrl: 'http://x/api/v1', adapter: adapter);
