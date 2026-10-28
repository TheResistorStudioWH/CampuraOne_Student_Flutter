import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../demo_data.dart';
import '../widgets/tile_settings.dart';
import 'course_schedule.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key, this.initialDate, this.schedule});
  final DateTime? initialDate;
  final CourseSchedule? schedule;
  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  static const _calendar = MethodChannel('campura.one/calendar');
  late DateTime selected = dayOnly(widget.initialDate ?? DateTime.now());
  CourseSchedule get schedule => widget.schedule ?? CourseSchedule.demo;

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (mounted && date != null) setState(() => selected = date);
  }

  Future<void> _export(bool week) async {
    final events = schedule.occurrences(
      week ? schedule.weekOf(selected) : [selected],
    );
    if (events.isEmpty) return;
    try {
      await _calendar.invokeMethod<void>('shareCalendar', {
        'name': week ? '演示课表-本周' : '演示课表-当天',
        'ics': exportCourseCalendar(events),
      });
    } on PlatformException {
      _calendarError('没有找到能分享日历文件的应用');
    } on MissingPluginException {
      _calendarError('日历导出需要在 Android 中打开');
    }
  }

  Future<void> _addCalendar(CampusCourse course) async {
    try {
      await _calendar.invokeMethod<void>('insertEvent', {
        'title': course.title,
        'location': course.location,
        'description': '本地演示课表 · ${course.teacher}',
        'startMillis': course.startOn(selected).millisecondsSinceEpoch,
        'endMillis': course.endOn(selected).millisecondsSinceEpoch,
      });
    } on PlatformException {
      _calendarError('没有找到可添加日程的日历应用');
    } on MissingPluginException {
      _calendarError('添加日程需要在 Android 中打开');
    }
  }

  void _calendarError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  Future<void> _showCourse(CampusCourse course) => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              course.title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text('${dateLabel(selected)}\n${course.timeLabel}'),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined),
              title: Text(course.location),
              subtitle: Text(course.teacher),
            ),
            FilledButton.icon(
              onPressed: () => _addCalendar(course),
              icon: const Icon(Icons.event_available_rounded),
              label: const Text('添加到系统日历'),
            ),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final courses = schedule.on(selected);
    final week = schedule.weekOf(selected);
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '日程表',
                          style: Theme.of(context).textTheme.headlineLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          dateLabel(selected),
                          key: const ValueKey('course-selected-date'),
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 10,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Chip(
                              label: Text('共 ${courses.length} 节课'),
                              backgroundColor: colors.primaryContainer,
                              side: BorderSide.none,
                            ),
                            Text(
                              '演示课表',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      IconButton.filledTonal(
                        tooltip: '关闭日程表',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                      ),
                      IconButton(
                        tooltip: '磁贴设置',
                        onPressed: () =>
                            showTileSettings(context, 'courseTable', '日程表'),
                        icon: const Icon(Icons.tune_rounded),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Column(
                      children: [
                        IconButton.filledTonal(
                          tooltip: '选择日程日期',
                          onPressed: _pickDate,
                          icon: const Icon(Icons.calendar_month_rounded),
                        ),
                        Expanded(
                          child: CourseDateRail(
                            selected: selected,
                            onSelected: (date) =>
                                setState(() => selected = date),
                          ),
                        ),
                        SizedBox(
                          height: 48,
                          child: Visibility(
                            visible: !DateUtils.isSameDay(
                              selected,
                              DateTime.now(),
                            ),
                            maintainSize: true,
                            maintainState: true,
                            maintainAnimation: true,
                            child: TextButton(
                              onPressed: () => setState(
                                () => selected = dayOnly(DateTime.now()),
                              ),
                              child: const Text('今天'),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 8, 16, 24),
                      children: [
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final label in CourseDayInsights(
                              courses,
                            ).labels)
                              Chip(
                                label: Text(label),
                                visualDensity: VisualDensity.compact,
                                backgroundColor: colors.secondaryContainer,
                                side: BorderSide.none,
                              ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _SectionHeading(
                          title:
                              week.any(
                                (day) =>
                                    DateUtils.isSameDay(day, DateTime.now()),
                              )
                              ? '本周课表'
                              : '当周课表',
                          subtitle:
                              '${week.first.month}/${week.first.day} — ${week.last.month}/${week.last.day}',
                          tooltip: '导出本周课程',
                          onExport: () => _export(true),
                        ),
                        const SizedBox(height: 8),
                        CourseWeekGrid(
                          schedule: schedule,
                          selected: selected,
                          onSelected: (date) => setState(() => selected = date),
                        ),
                        const SizedBox(height: 24),
                        _SectionHeading(
                          title: DateUtils.isSameDay(selected, DateTime.now())
                              ? '今日日程'
                              : '当日日程',
                          tooltip: '导出当天课程',
                          onExport: courses.isEmpty
                              ? null
                              : () => _export(false),
                        ),
                        const SizedBox(height: 12),
                        if (courses.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 30),
                            child: Column(
                              children: [
                                Icon(Icons.event_available_rounded, size: 40),
                                SizedBox(height: 12),
                                Text('这一天没有课程'),
                              ],
                            ),
                          )
                        else
                          CourseDayTimeline(
                            courses: courses,
                            onOpen: _showCourse,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.tooltip,
    this.subtitle,
    this.onExport,
  });
  final String title, tooltip;
  final String? subtitle;
  final VoidCallback? onExport;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            if (subtitle != null)
              Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
          ],
        ),
      ),
      IconButton(
        tooltip: tooltip,
        onPressed: onExport,
        icon: const Icon(Icons.ios_share_rounded, size: 20),
      ),
    ],
  );
}

class CourseDateRail extends StatefulWidget {
  const CourseDateRail({
    super.key,
    required this.selected,
    required this.onSelected,
  });
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  @override
  State<CourseDateRail> createState() => _CourseDateRailState();
}

class _CourseDateRailState extends State<CourseDateRail> {
  late DateTime center = dayOnly(widget.selected);
  double? touch;
  DateTime? lastWeekJump;
  @override
  void didUpdateWidget(CourseDateRail old) {
    super.didUpdateWidget(old);
    if ((touch == null &&
            DateUtils.isSameDay(widget.selected, DateTime.now())) ||
        widget.selected.difference(center).inDays.abs() > 3)
      center = dayOnly(widget.selected);
  }

  void _week(int offset) {
    setState(() => center = dayOffset(center, offset * 7));
    widget.onSelected(dayOffset(widget.selected, offset * 7));
  }

  void _selectAt(double y, double height) {
    setState(() => touch = y);
    if (y < 0 || y > height) {
      if (lastWeekJump == null ||
          DateTime.now().difference(lastWeekJump!).inMilliseconds > 650) {
        _week(y < 0 ? -1 : 1);
        lastWeekJump = DateTime.now();
      }
      return;
    }
    final index = ((y - 20) / math.max(1, height - 40) * 6).round().clamp(0, 6);
    final date = dayOffset(center, index - 3);
    if (!DateUtils.isSameDay(date, widget.selected)) {
      HapticFeedback.selectionClick();
      widget.onSelected(date);
    }
  }

  void _release() => setState(() {
    touch = null;
    lastWeekJump = null;
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Column(
      children: [
        IconButton(
          tooltip: '上一周',
          onPressed: () => _week(-1),
          icon: const Icon(Icons.keyboard_arrow_up_rounded),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, size) => Semantics(
              label: '课表日期时间轴',
              value: dateLabel(widget.selected),
              onIncrease: () =>
                  widget.onSelected(dayOffset(widget.selected, 1)),
              onDecrease: () =>
                  widget.onSelected(dayOffset(widget.selected, -1)),
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _selectAt(d.localPosition.dy, size.maxHeight),
                onTapUp: (_) => _release(),
                onTapCancel: _release,
                onVerticalDragStart: (d) =>
                    _selectAt(d.localPosition.dy, size.maxHeight),
                onVerticalDragUpdate: (d) =>
                    _selectAt(d.localPosition.dy, size.maxHeight),
                onVerticalDragEnd: (_) => _release(),
                onVerticalDragCancel: _release,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    for (var tick = 0; tick <= 24; tick++)
                      Positioned(
                        left: 0,
                        top:
                            20 +
                            tick / 24 * math.max(1, size.maxHeight - 40) -
                            16,
                        height: 32,
                        width: 64,
                        child: _tick(
                          context,
                          tick,
                          20 + tick / 24 * math.max(1, size.maxHeight - 40),
                          colors,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: '下一周',
          onPressed: () => _week(1),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
        ),
      ],
    );
  }

  Widget _tick(BuildContext context, int tick, double y, ColorScheme colors) {
    final day = dayOffset(center, tick ~/ 4 - 3);
    final isDay = tick % 4 == 0;
    final isToday = isDay && DateUtils.isSameDay(day, DateTime.now());
    final selected = isDay && DateUtils.isSameDay(day, widget.selected);
    final influence = touch == null || MediaQuery.disableAnimationsOf(context)
        ? 0.0
        : (1 - (touch! - y).abs() / 48).clamp(0.0, 1.0);
    return Align(
      alignment: Alignment.centerLeft,
      child: isDay && (tick == 0 || tick == 24 || isToday || selected)
          ? Padding(
              padding: const EdgeInsets.only(left: 7),
              child: Transform.scale(
                alignment: Alignment.centerLeft,
                scale: 1 + influence * .25,
                child: Text(
                  '${isToday ? '今天' : '周${weekdayLabel(day)}'} ${day.day}',
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontSize: 10,
                    color: selected || isToday
                        ? colors.primary
                        : colors.onSurface,
                    fontWeight: selected ? FontWeight.bold : null,
                  ),
                ),
              ),
            )
          : Container(
              width: (isDay ? 14 : 7) + influence * 10,
              height: isDay ? 2 : 1,
              color: influence > .5 ? colors.primary : colors.outlineVariant,
            ),
    );
  }
}

class CourseWeekGrid extends StatelessWidget {
  const CourseWeekGrid({
    super.key,
    required this.schedule,
    required this.selected,
    required this.onSelected,
  });
  final CourseSchedule schedule;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;
  @override
  Widget build(BuildContext context) {
    final dates = schedule.weekOf(selected);
    final starts =
        dates.expand(schedule.on).map((c) => c.startMinutes).toSet().toList()
          ..sort();
    final colors = Theme.of(context).colorScheme;
    const rowHeight = 102.0;
    return SizedBox(
      height: 64 + math.max(1, starts.length) * rowHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 45,
            child: Column(
              children: [
                const SizedBox(height: 64),
                for (final start in starts)
                  SizedBox(
                    height: rowHeight,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        minuteLabel(start),
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final width = math.max(84.0, constraints.maxWidth / 7);
                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      for (final day in dates)
                        InkWell(
                          onTap: () => onSelected(day),
                          child: Container(
                            width: width,
                            decoration: BoxDecoration(
                              color: DateUtils.isSameDay(day, DateTime.now())
                                  ? colors.primaryContainer.withValues(
                                      alpha: .45,
                                    )
                                  : null,
                              border: Border.all(
                                color: DateUtils.isSameDay(day, selected)
                                    ? colors.primary
                                    : colors.outlineVariant,
                                width: DateUtils.isSameDay(day, selected)
                                    ? 1.5
                                    : .5,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 63,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        [
                                          'MON',
                                          'TUE',
                                          'WED',
                                          'THU',
                                          'FRI',
                                          'SAT',
                                          'SUN',
                                        ][day.weekday - 1],
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall,
                                      ),
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          const Icon(
                                            Icons.calendar_today_rounded,
                                            size: 13,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${day.day}',
                                            style: Theme.of(context)
                                                .textTheme
                                                .titleMedium,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (starts.isEmpty)
                                  const SizedBox(
                                    height: rowHeight - 2,
                                    child: Center(child: Text('—')),
                                  ),
                                for (final start in starts)
                                  Container(
                                    height: rowHeight,
                                    width: width,
                                    padding: const EdgeInsets.all(5),
                                    decoration: BoxDecoration(
                                      border: Border(
                                        top: BorderSide(
                                          color: colors.outlineVariant
                                              .withValues(alpha: .5),
                                        ),
                                      ),
                                    ),
                                    child: SingleChildScrollView(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          for (final c
                                              in schedule
                                                  .on(day)
                                                  .where(
                                                    (c) =>
                                                        c.startMinutes == start,
                                                  ))
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                bottom: 4,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    c.title,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelMedium,
                                                  ),
                                                  Text(
                                                    c.location,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: Theme.of(context)
                                                        .textTheme
                                                        .labelSmall
                                                        ?.copyWith(
                                                          color: colors
                                                              .onSurfaceVariant,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CourseDayTimeline extends StatelessWidget {
  const CourseDayTimeline({
    super.key,
    required this.courses,
    required this.onOpen,
    this.compact = false,
  });
  final List<CampusCourse> courses;
  final ValueChanged<CampusCourse> onOpen;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final placements = CoursePlacement.make(courses);
    final first = courses.fold<int>(480, (v, c) => math.min(v, c.startMinutes));
    final last = courses.fold<int>(1200, (v, c) => math.max(v, c.endMinutes));
    final start = first ~/ 60 * 60, end = (last / 60).ceil() * 60;
    final scale = compact ? .45 : 1.05;
    final height = (end - start) * scale + 28;
    final colors = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, bounds) {
        final rail = compact ? 34.0 : 44.0;
        return SizedBox(
          height: height,
          child: Stack(
            children: [
              for (var minute = start; minute <= end; minute += 60)
                Positioned(
                  top: (minute - start) * scale,
                  left: 0,
                  right: 0,
                  child: Row(
                    children: [
                      SizedBox(
                        width: rail,
                        child: Text(
                          minuteLabel(minute),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(fontSize: compact ? 9 : 10),
                        ),
                      ),
                      Expanded(
                        child: Divider(height: 1, color: colors.outlineVariant),
                      ),
                    ],
                  ),
                ),
              for (final p in placements)
                Positioned(
                  top: (p.course.startMinutes - start) * scale + 1,
                  left:
                      rail +
                      (bounds.maxWidth - rail) * p.column / p.columns +
                      2,
                  width: math.max(1, (bounds.maxWidth - rail) / p.columns - 4),
                  height: math.max(
                    18,
                    (p.course.endMinutes - p.course.startMinutes) * scale - 3,
                  ),
                  child: Material(
                    color: colors.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => onOpen(p.course),
                      child: Padding(
                        padding: EdgeInsets.all(compact ? 5 : 8),
                        child: LayoutBuilder(
                          builder: (context, size) => SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.course.title,
                                  style: compact
                                      ? Theme.of(context).textTheme.labelSmall
                                      : Theme.of(context).textTheme.titleSmall,
                                ),
                                if (!compact && size.maxHeight > 40) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    p.course.timeLabel,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                  Text(
                                    p.course.location,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
