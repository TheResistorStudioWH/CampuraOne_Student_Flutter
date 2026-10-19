import 'dart:convert';

import 'package:campura_one_student/src/announcement_feed.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  http.Response jsonResponse(String body) => http.Response.bytes(
    utf8.encode(body),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );

  test(
    'authenticated notices use only AI summaries with visible source IDs',
    () async {
      final paths = <String>[];
      final client = MockClient((request) async {
        paths.add(request.url.path);
        expect(request.headers['Authorization'], 'Bearer student-token');
        if (request.url.path.endsWith('/announcements.php')) {
          return jsonResponse(
            '{"code":200,"message":"success","data":['
            '{"announceID":11,"type":0,"content":"演示短通知"},'
            '{"announceID":12,"type":2,"content":"# 演示重要通知"}]}',
          );
        }
        return jsonResponse(
          '{"code":200,"message":"success","data":'
          '{"summary":"活动时间已更新","sourceIDs":[11],"isAI":true}}',
        );
      });
      final feed = AnnouncementFeed(
        baseUri: Uri.parse('https://example.test'),
        client: client,
      );
      final result = await feed.load('student-token');
      expect(result.announcements.length, 2);
      expect(result.summary, '活动时间已更新');
      expect(paths, [
        '/api/download/announcements.php',
        '/api/OnlyAI/announcement_summary.php',
      ]);
      feed.dispose();
    },
  );

  test('summary with an unseen source is discarded', () async {
    final client = MockClient(
      (request) async => request.url.path.endsWith('/announcements.php')
          ? jsonResponse(
              '{"code":200,"data":[{"announceID":11,"type":0,"content":"通知"}]}',
            )
          : jsonResponse(
              '{"code":200,"data":{"summary":"错误摘要","sourceIDs":[99],"isAI":true}}',
            ),
    );
    final feed = AnnouncementFeed(
      baseUri: Uri.parse('https://example.test'),
      client: client,
    );
    final result = await feed.load('student-token');
    expect(result.announcements.single.id, 11);
    expect(result.summary, isNull);
    feed.dispose();
  });
}
