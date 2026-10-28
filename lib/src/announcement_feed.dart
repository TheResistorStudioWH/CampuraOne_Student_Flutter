import 'dart:convert';

import 'package:http/http.dart' as http;

import 'demo_data.dart';

/// SQL timestamps are Asia/Shanghai; timestamps with an offset keep that offset.
DateTime? parseCampusDate(Object? value) {
  if (value == null || value == '') return null;
  if (value is! String) throw const FormatException('Invalid date');
  final match = RegExp(
    r'^(\d{4})[-/](\d{2})[-/](\d{2})(?:[T ](\d{2}):(\d{2}):(\d{2})(\.\d+)?)?(Z|[+-]\d{2}:?\d{2})?$',
  ).firstMatch(value.trim());
  if (match == null) throw const FormatException('Invalid date');
  final y = int.parse(match[1]!),
      m = int.parse(match[2]!),
      d = int.parse(match[3]!);
  final h = int.parse(match[4] ?? '0'),
      min = int.parse(match[5] ?? '0'),
      sec = int.parse(match[6] ?? '0');
  final check = DateTime.utc(y, m, d, h, min, sec);
  if (check.year != y ||
      check.month != m ||
      check.day != d ||
      h > 23 ||
      min > 59 ||
      sec > 59) {
    throw const FormatException('Impossible date');
  }
  final zone = match[8] ?? '+08:00';
  if (zone != 'Z') {
    final digits = zone.substring(1).replaceAll(':', '');
    if (int.parse(digits.substring(0, 2)) > 23 ||
        int.parse(digits.substring(2)) > 59) {
      throw const FormatException('Invalid offset');
    }
  }
  return DateTime.parse(
    '${match[1]}-${match[2]}-${match[3]}T${match[4] ?? '00'}:${match[5] ?? '00'}:${match[6] ?? '00'}${match[7] ?? ''}$zone',
  );
}

class AnnouncementSummary {
  const AnnouncementSummary(this.text, this.sourceIds);
  final String text;
  final Set<int> sourceIds;
  bool validFor(List<CampusAnnouncement> notices) =>
      sourceIds.isNotEmpty &&
      sourceIds.every((id) => notices.any((n) => n.id == id));
}

class AnnouncementFeed {
  AnnouncementFeed({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client();
  final Uri baseUri;
  final http.Client _client;

  Future<List<CampusAnnouncement>> loadNotices(String token) async {
    final response = await _get('/api/download/announcements.php', token);
    final raw = response['data'];
    if (raw is! List) throw const FormatException('Invalid notices');
    return [for (final value in raw) _notice(value)];
  }

  CampusAnnouncement _notice(Object? raw) {
    if (raw is! Map<String, dynamic> ||
        raw['announceID'] is! int ||
        raw['content'] is! String ||
        raw['type'] is! int ||
        (raw['type'] as int) < 0 ||
        (raw['type'] as int) > 2) {
      throw const FormatException('Invalid notice');
    }
    return CampusAnnouncement(
      raw['announceID'] as int,
      raw['content'] as String,
      raw['type'] as int,
      startTime: parseCampusDate(raw['startTime']),
      endTime: parseCampusDate(raw['endTime']),
      createdAt: parseCampusDate(raw['createdAt']),
      updatedAt: parseCampusDate(raw['updatedAt']),
    );
  }

  Future<AnnouncementSummary?> loadSummary(String token) async {
    final response = await _get('/api/OnlyAI/announcement_summary.php', token);
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['isAI'] != true ||
        data['summary'] is! String ||
        data['sourceIDs'] is! List) {
      return null;
    }
    final text = (data['summary'] as String).trim();
    final ids = data['sourceIDs'] as List;
    if (text.isEmpty || ids.isEmpty || ids.any((id) => id is! int)) return null;
    return AnnouncementSummary(text, ids.cast<int>().toSet());
  }

  Future<AnnouncementFeedResult> load(String token) async {
    final notices = (await loadNotices(token))
        .where((n) => n.isActive(DateTime.now()))
        .toList();
    AnnouncementSummary? summary;
    if (notices.isNotEmpty) {
      try {
        summary = await loadSummary(token);
      } catch (_) {
        /* Keep originals available. */
      }
    }
    final current = notices.where((n) => n.isActive(DateTime.now())).toList();
    return AnnouncementFeedResult(
      current,
      summary?.validFor(current) == true ? summary!.text : null,
    );
  }

  Future<Map<String, dynamic>> _get(String path, String token) async {
    if (token.trim().isEmpty || baseUri.scheme != 'https') {
      throw ArgumentError('HTTPS and student authentication required');
    }
    final response = await _client
        .get(
          baseUri.resolve(path),
          headers: {
            'Authorization': 'Bearer $token',
            'Cache-Control': 'no-cache, no-store',
            'Pragma': 'no-cache',
          },
        )
        .timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) {
      throw StateError('Request failed: ${response.statusCode}');
    }
    final data = jsonDecode(utf8.decode(response.bodyBytes));
    if (data is! Map<String, dynamic> || data['code'] != 200) {
      throw const FormatException('Invalid API response');
    }
    return data;
  }

  void dispose() => _client.close();
}

class AnnouncementFeedResult {
  const AnnouncementFeedResult(this.announcements, this.summary);
  final List<CampusAnnouncement> announcements;
  final String? summary;
}
