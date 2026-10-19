import 'dart:convert';

import 'package:http/http.dart' as http;

import 'demo_data.dart';

/// Uses the same authenticated notice and summary endpoints as the iOS app.
/// The demo shell has no student token, so it never calls this service yet.
class AnnouncementFeed {
  AnnouncementFeed({required this.baseUri, http.Client? client})
    : _client = client ?? http.Client();

  final Uri baseUri;
  final http.Client _client;

  Future<AnnouncementFeedResult> load(String studentToken) async {
    if (studentToken.trim().isEmpty) {
      throw ArgumentError.value(studentToken, 'studentToken', 'required');
    }
    if (baseUri.scheme != 'https') {
      throw ArgumentError.value(
        baseUri,
        'baseUri',
        'HTTPS required for Bearer authentication',
      );
    }
    final headers = {'Authorization': 'Bearer $studentToken'};
    final notices = await _get('/api/download/announcements.php', headers);
    final rawNotices = notices['data'];
    if (rawNotices is! List) {
      throw const FormatException('Invalid announcements data');
    }
    final announcements = <CampusAnnouncement>[];
    for (final value in rawNotices) {
      if (value is! Map<String, dynamic>) continue;
      final id = value['announceID'];
      final type = value['type'];
      final content = value['content'];
      if (id is int &&
          type is int &&
          type >= 0 &&
          type <= 2 &&
          content is String) {
        announcements.add(CampusAnnouncement(id, content, type));
      }
    }

    String? summary;
    if (announcements.isNotEmpty) {
      try {
        final response = await _get(
          '/api/OnlyAI/announcement_summary.php',
          headers,
        );
        final data = response['data'];
        if (data is Map<String, dynamic> && data['isAI'] == true) {
          final sourceIds = data['sourceIDs'];
          final text = data['summary'];
          final visibleIds = announcements.map((item) => item.id).toSet();
          if (sourceIds is List &&
              sourceIds.isNotEmpty &&
              sourceIds.every((id) => id is int && visibleIds.contains(id)) &&
              text is String &&
              text.trim().isNotEmpty) {
            summary = text
                .replaceAll(RegExp(r'\[\d+\]'), '')
                .replaceAll(RegExp(r'\s+'), ' ')
                .trim();
          }
        }
      } catch (_) {
        // Original notices remain available when AI is unconfigured or unavailable.
      }
    }
    return AnnouncementFeedResult(announcements, summary);
  }

  Future<Map<String, dynamic>> _get(
    String path,
    Map<String, String> headers,
  ) async {
    final response = await _client.get(baseUri.resolve(path), headers: headers);
    if (response.statusCode != 200) {
      throw StateError('Request failed: ${response.statusCode}');
    }
    final value = jsonDecode(response.body);
    if (value is! Map<String, dynamic> || value['code'] != 200) {
      throw const FormatException('Invalid API response');
    }
    return value;
  }

  void dispose() => _client.close();
}

class AnnouncementFeedResult {
  const AnnouncementFeedResult(this.announcements, this.summary);
  final List<CampusAnnouncement> announcements;
  final String? summary;
}
