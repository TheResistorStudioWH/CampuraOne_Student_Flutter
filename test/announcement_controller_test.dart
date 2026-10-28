import 'dart:async';
import 'dart:convert';

import 'package:campura_one_student/src/announcement_controller.dart';
import 'package:campura_one_student/src/announcement_feed.dart';
import 'package:campura_one_student/src/demo_data.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

http.Response response(Object data) => http.Response.bytes(
  utf8.encode(jsonEncode({'code': 200, 'data': data})),
  200,
);
Future<void> flush() async {
  await Future<void>.delayed(Duration.zero);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('API dates are Shanghai by default and reject impossible dates', () {
    expect(parseCampusDate('2026-10-28 08:00:00'), DateTime.utc(2026, 10, 28));
    expect(
      parseCampusDate('2026-10-28T08:00:00+08:00'),
      DateTime.utc(2026, 10, 28),
    );
    expect(
      parseCampusDate('2026-10-28T08:00:00Z'),
      DateTime.utc(2026, 10, 28, 8),
    );
    expect(() => parseCampusDate('2026-02-30'), throwsFormatException);
    expect(() => parseCampusDate('2026-01-01 25:00:00'), throwsFormatException);
    expect(parseCampusDate(null), isNull);
  });
  test('demo expiry is inclusive and Markdown uses date then ID order without network', () async {
    var now = DateTime.utc(2026, 10, 28);
    var calls = 0;
    final feed = AnnouncementFeed(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((_) async {
        calls++;
        return response([]);
      }),
    );
    final store = AnnouncementController(
      feed: feed,
      automatic: false,
      clock: () => now,
      demoNotices: [
        CampusAnnouncement(1, 'old', 2, endTime: now),
        CampusAnnouncement(3, 'new', 2, createdAt: now),
        CampusAnnouncement(2, 'new', 2, createdAt: now),
        CampusAnnouncement(
          4,
          'future',
          2,
          startTime: now.add(const Duration(days: 1)),
        ),
      ],
    )..start();
    expect(store.important.map((n) => n.id), [3, 2, 1]);
    now = now.add(const Duration(seconds: 1));
    await store.tick();
    expect(store.important.map((n) => n.id), [3, 2]);
    expect(calls, 0);
    expect(store.summary, isNull);
    store.dispose();
    feed.dispose();
  });
  test('summary retries at 5 and 30 seconds, caps at three and resumes after cooldown', () async {
    var now = DateTime.utc(2026, 10, 28);
    var summaries = 0;
    final feed = AnnouncementFeed(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        expect(request.headers['Cache-Control'], contains('no-store'));
        if (request.url.path.endsWith('announcements.php'))
          return response([
            {'announceID': 1, 'type': 0, 'content': '通知'},
          ]);
        summaries++;
        return http.Response('unavailable', 503);
      }),
    );
    final store = AnnouncementController(
      feed: feed,
      token: 'test',
      automatic: false,
      clock: () => now,
    )..start();
    await flush();
    expect(summaries, 1);
    expect(store.notices, hasLength(1));
    now = now.add(const Duration(seconds: 4));
    await store.tick();
    expect(summaries, 1);
    now = now.add(const Duration(seconds: 1));
    await store.tick();
    expect(summaries, 2);
    now = now.add(const Duration(seconds: 30));
    await store.tick();
    expect(summaries, 3);
    now = now.add(const Duration(minutes: 2));
    await store.tick();
    expect(summaries, 3);
    store.pause();
    store.start();
    await flush();
    expect(summaries, 4);
    store.pause();
    store.start();
    await flush();
    expect(summaries, 4);
    store.dispose();
    feed.dispose();
  });
  test('unchanged notice refresh does not regenerate summary; edits and expiry invalidate it', () async {
    var now = DateTime.utc(2026, 10, 28);
    var content = '第一版';
    var summaryCalls = 0;
    var failList = false;
    final feed = AnnouncementFeed(
      baseUri: Uri.parse('https://example.test'),
      client: MockClient((request) async {
        if (request.url.path.endsWith('announcements.php')) {
          if (failList) return http.Response('unavailable', 503);
          return response([
            {
              'announceID': 1,
              'type': 2,
              'content': content,
              'endTime': '2026-10-28T00:10:00Z',
            },
          ]);
        }
        summaryCalls++;
        return response({
          'summary': '已核对：$content',
          'sourceIDs': [1],
          'isAI': true,
        });
      }),
    );
    final store = AnnouncementController(
      feed: feed,
      token: 'test',
      automatic: false,
      clock: () => now,
    )..start();
    await flush();
    expect(summaryCalls, 1);
    expect(store.summary, contains('第一版'));
    now = now.add(const Duration(minutes: 1));
    await store.tick();
    expect(summaryCalls, 1);
    content = '第二版';
    await store.refresh();
    expect(summaryCalls, 2);
    expect(store.summary, contains('第二版'));
    failList = true;
    await store.refresh();
    expect(store.notices, hasLength(1));
    expect(store.loadFailed, isTrue);
    now = DateTime.utc(2026, 10, 28, 0, 10, 1);
    await store.tick();
    expect(store.notices, isEmpty);
    expect(store.summary, isNull);
    store.dispose();
    feed.dispose();
  });
  test(
    'summary arriving after pause or expiration never becomes visible',
    () async {
      var now = DateTime.utc(2026, 10, 28);
      final pending = Completer<http.Response>();
      final feed = AnnouncementFeed(
        baseUri: Uri.parse('https://example.test'),
        client: MockClient((request) async {
          if (request.url.path.endsWith('announcements.php'))
            return response([
              {
                'announceID': 1,
                'type': 0,
                'content': '通知',
                'endTime': '2026-10-28T00:00:01Z',
              },
            ]);
          return pending.future;
        }),
      );
      final store = AnnouncementController(
        feed: feed,
        token: 'test',
        automatic: false,
        clock: () => now,
      )..start();
      await flush();
      now = now.add(const Duration(seconds: 2));
      await store.tick();
      store.pause();
      pending.complete(
        response({
          'summary': '旧摘要',
          'sourceIDs': [1],
          'isAI': true,
        }),
      );
      await flush();
      expect(store.summary, isNull);
      expect(store.notices, isEmpty);
      store.dispose();
      feed.dispose();
    },
  );
}
