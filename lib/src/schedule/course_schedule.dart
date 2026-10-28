import '../demo_data.dart';

DateTime dayOnly(DateTime date) => DateTime(date.year, date.month, date.day);
DateTime dayOffset(DateTime date, int days) =>
    DateTime(date.year, date.month, date.day + days);
String weekdayLabel(DateTime day) => '一二三四五六日'[day.weekday - 1];
String dateLabel(DateTime day) => '${day.year}年${day.month}月${day.day}日';
String minuteLabel(int value) =>
    '${(value ~/ 60).toString().padLeft(2, '0')}:${(value % 60).toString().padLeft(2, '0')}';

/// One source for the dashboard, map status and expanded schedule.
class CourseSchedule {
  const CourseSchedule(this.courses);
  static final demo = CourseSchedule(DemoData.courses);
  final List<CampusCourse> courses;

  List<CampusCourse> on(DateTime date) =>
      courses.where((c) => c.weekday == date.weekday).toList()
        ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));

  List<DateTime> weekOf(DateTime date) =>
      List.generate(7, (i) => dayOffset(date, i - date.weekday + 1));

  CourseOccurrence? nextAfter(DateTime now) {
    for (var i = 0; i <= 7; i++) {
      final date = dayOffset(now, i);
      for (final course in on(date)) {
        if (course.startOn(date).isAfter(now)) {
          return CourseOccurrence(course, date);
        }
      }
    }
    return null;
  }

  List<CourseOccurrence> occurrences(Iterable<DateTime> days) => [
    for (final day in days)
      for (final course in on(day)) CourseOccurrence(course, day),
  ];
}

class CourseOccurrence {
  const CourseOccurrence(this.course, this.day);
  final CampusCourse course;
  final DateTime day;
}

class CourseDayInsights {
  CourseDayInsights(List<CampusCourse> courses) {
    final valid = courses.where((c) => c.endMinutes > c.startMinutes).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    bool occupied(int start, int end) =>
        valid.any((c) => c.startMinutes < end && c.endMinutes > start);
    final first = valid.firstOrNull?.startHour;
    earlyHour = first != null && first >= 8 && first < 10
        ? 8
        : first != null && first >= 10 && first < 12
        ? 10
        : null;
    morningFree = !occupied(360, 720);
    afternoonFree = !occupied(780, 1080);
    eveningStudy = occupied(1080, 1440);
    final morning = valid.where((c) => c.startMinutes < 720);
    final afternoon = valid.where(
      (c) => c.startMinutes >= 720 && c.startMinutes < 1080,
    );
    napMinutes = morning.isEmpty || afternoon.isEmpty
        ? 0
        : (afternoon.first.startMinutes -
                  morning
                      .map((c) => c.endMinutes)
                      .reduce((a, b) => a > b ? a : b))
              .clamp(0, 1440);
  }
  late final int? earlyHour;
  late final bool morningFree, afternoonFree, eveningStudy;
  late final int napMinutes;
  List<String> get labels => [
    if (earlyHour != null) '早$earlyHour',
    if (morningFree) '上午空闲',
    if (afternoonFree) '下午空闲',
    if (eveningStudy) '晚自习',
    if (napMinutes >= 30)
      '午休 ${napMinutes ~/ 60 > 0 ? '${napMinutes ~/ 60}小时' : ''}${napMinutes % 60 > 0 ? '${napMinutes % 60}分钟' : ''}',
  ];
}

class CoursePlacement {
  const CoursePlacement(this.course, this.column, this.columns);
  final CampusCourse course;
  final int column, columns;

  static List<CoursePlacement> make(List<CampusCourse> courses) {
    final sorted = courses.where((c) => c.endMinutes > c.startMinutes).toList()
      ..sort((a, b) => a.startMinutes.compareTo(b.startMinutes));
    final result = <CoursePlacement>[];
    var group = <(CampusCourse, int)>[];
    var ends = <int>[];
    var groupEnd = -1;
    void flush() {
      result.addAll(group.map((e) => CoursePlacement(e.$1, e.$2, ends.length)));
      group = [];
      ends = [];
    }

    for (final course in sorted) {
      if (course.startMinutes >= groupEnd) {
        flush();
        groupEnd = course.endMinutes;
      }
      var lane = ends.indexWhere((end) => end <= course.startMinutes);
      if (lane < 0) {
        lane = ends.length;
        ends.add(course.endMinutes);
      } else {
        ends[lane] = course.endMinutes;
      }
      group.add((course, lane));
      if (course.endMinutes > groupEnd) groupEnd = course.endMinutes;
    }
    flush();
    return result;
  }
}

/// UTF-8 RFC 5545 export; local demo events carry an explicit demo description.
String exportCourseCalendar(
  List<CourseOccurrence> occurrences, {
  DateTime? generatedAt,
}) {
  String stamp(DateTime value) =>
      '${value.toUtc().toIso8601String().replaceAll(RegExp('[-:]'), '').split('.').first}Z';
  String escape(String text) => text
      .replaceAll('\\', '\\\\')
      .replaceAll('\n', r'\n')
      .replaceAll(',', r'\,')
      .replaceAll(';', r'\;');
  final now = generatedAt ?? DateTime.now();
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Campura One//Student Demo//ZH',
    'CALSCALE:GREGORIAN',
  ];
  for (final (index, event) in occurrences.indexed) {
    final c = event.course;
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:demo-${c.startOn(event.day).millisecondsSinceEpoch}-$index@campura.one',
      'DTSTAMP:${stamp(now)}',
      'DTSTART:${stamp(c.startOn(event.day))}',
      'DTEND:${stamp(c.endOn(event.day))}',
      'SUMMARY:${escape(c.title)}',
      'LOCATION:${escape(c.location)}',
      'DESCRIPTION:${escape('本地演示课表 · ${c.teacher}')}',
      'END:VEVENT',
    ]);
  }
  lines.add('END:VCALENDAR');
  // Folding at 70 UTF-8 bytes also handles Chinese titles without splitting a rune.
  return '${lines.map((line) {
    final out = StringBuffer();
    var bytes = 0;
    for (final rune in line.runes) {
      final size = rune < 128
          ? 1
          : rune < 2048
          ? 2
          : rune < 65536
          ? 3
          : 4;
      if (bytes + size > 70) {
        out.write('\r\n ');
        bytes = 1;
      }
      out.writeCharCode(rune);
      bytes += size;
    }
    return out.toString();
  }).join('\r\n')}\r\n';
}
