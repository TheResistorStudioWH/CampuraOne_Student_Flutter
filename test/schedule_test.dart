import 'dart:convert';

import 'package:campura_one_student/src/demo_data.dart';
import 'package:campura_one_student/src/schedule/course_schedule.dart';
import 'package:campura_one_student/src/widgets/tile_settings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

CampusCourse course(
  int start,
  int end, {
  String title = '课程',
  int weekday = 1,
}) => CampusCourse(
  title,
  weekday,
  start ~/ 60,
  start % 60,
  end ~/ 60,
  end % 60,
  '教学楼 A203',
  '老师',
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'day insights use actual course boundaries for early classes and lunch',
    () {
      final value = CourseDayInsights([
        course(480, 750),
        course(840, 950),
        course(1070, 1100),
      ]);
      expect(value.earlyHour, 8);
      expect(value.napMinutes, 90);
      expect(value.morningFree, false);
      expect(value.afternoonFree, false);
      expect(value.eveningStudy, true);
      expect(CourseDayInsights([course(600, 720)]).earlyHour, 10);
      expect(CourseDayInsights([course(600, 720)]).napMinutes, 0);
      expect(
        CourseDayInsights([course(660, 900), course(840, 950)]).napMinutes,
        0,
      );
      expect(CourseDayInsights([]).labels, ['上午空闲', '下午空闲']);
      expect(CourseDayInsights([course(720, 780)]).afternoonFree, true);
      expect(CourseDayInsights([course(1020, 1080)]).eveningStudy, false);
    },
  );
  test(
    'overlap lanes are shared through a connected group and reset afterward',
    () {
      final placements = CoursePlacement.make([
        course(480, 600),
        course(540, 660),
        course(600, 720),
        course(720, 780),
      ]);
      expect(placements.map((e) => e.column), [0, 1, 0, 0]);
      expect(placements.map((e) => e.columns), [2, 2, 2, 1]);
    },
  );
  test(
    'week starts Monday and next course excludes a course already started',
    () {
      final schedule = CourseSchedule([course(480, 600), course(600, 720)]);
      final monday = DateTime(2026, 10, 26, 8, 1);
      expect(schedule.weekOf(dayOffset(monday, 6)).first, dayOnly(monday));
      expect(schedule.nextAfter(monday)!.course.startHour, 10);
      expect(
        schedule.nextAfter(DateTime(2026, 10, 26, 11))!.day,
        DateTime(2026, 11, 2),
      );
    },
  );
  test(
    'ICS escapes content, folds UTF-8 safely and exports selected occurrences',
    () {
      final value = course(
        480,
        600,
        title: '课程,标题;换行\n${List.filled(40, '中').join()}',
      );
      final result = exportCourseCalendar([
        CourseOccurrence(value, DateTime(2026, 10, 26)),
      ], generatedAt: DateTime.utc(2026));
      expect(result, contains('BEGIN:VEVENT\r\n'));
      expect(result.replaceAll('\r\n ', ''), contains(r'SUMMARY:课程\,标题\;换行\n'));
      expect(result, endsWith('END:VCALENDAR\r\n'));
      for (final line in result.split('\r\n')) {
        expect(utf8.encode(line).length, lessThanOrEqualTo(75));
      }
    },
  );
  test(
    'tile mute preferences expire at midnight or seven days and stay isolated',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final settings = TileNotificationSettings(prefs, 'courseTable');
      final now = DateTime(2026, 10, 28, 23, 55);
      await settings.set(TileNotificationPreference.muteToday, at: now);
      expect(settings.read(at: now), TileNotificationPreference.muteToday);
      expect(
        settings.read(at: DateTime(2026, 10, 29)),
        TileNotificationPreference.on,
      );
      await settings.set(TileNotificationPreference.muteWeek, at: now);
      expect(
        settings.read(at: now.add(const Duration(days: 6))),
        TileNotificationPreference.muteWeek,
      );
      expect(
        settings.read(at: now.add(const Duration(days: 7))),
        TileNotificationPreference.on,
      );
      expect(
        TileNotificationSettings(prefs, 'schoolCalendar').read(at: now),
        TileNotificationPreference.on,
      );
      await settings.set(TileNotificationPreference.off, at: now);
      expect(
        settings.read(at: now.add(const Duration(days: 365))),
        TileNotificationPreference.off,
      );
    },
  );
}
