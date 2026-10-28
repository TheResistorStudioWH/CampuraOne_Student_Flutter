import 'package:flutter/material.dart';

import '../demo_data.dart';
import '../schedule/course_schedule.dart';
import '../widgets/detail_scaffold.dart';

/// Five dates are visible, with a fixed center highlight. Page snapping is native
/// Flutter physics; vertical gestures remain owned by the dashboard scroll view.
class CalendarDateWheel extends StatefulWidget {
  const CalendarDateWheel({
    super.key,
    required this.selected,
    required this.onChanged,
  });
  final DateTime selected;
  final ValueChanged<DateTime> onChanged;
  @override
  State<CalendarDateWheel> createState() => _CalendarDateWheelState();
}

class _CalendarDateWheelState extends State<CalendarDateWheel> {
  static final epoch = DateTime(2000);
  int index(DateTime d) => DateTime.utc(
    d.year,
    d.month,
    d.day,
  ).difference(DateTime.utc(2000)).inDays;
  late final controller = PageController(
    initialPage: index(widget.selected),
    viewportFraction: .2,
  );
  @override
  void didUpdateWidget(CalendarDateWheel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (controller.hasClients &&
        (controller.page ?? 0).round() != index(widget.selected)) {
      controller.jumpToPage(index(widget.selected));
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    return SizedBox(
      height: 70 * scale.clamp(1, 1.8),
      child: Stack(
        children: [
          Align(
            child: FractionallySizedBox(
              widthFactor: .2,
              heightFactor: 1,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          PageView.builder(
            controller: controller,
            itemCount: 36525,
            onPageChanged: (i) => widget.onChanged(dayOffset(epoch, i)),
            itemBuilder: (context, i) {
              final day = dayOffset(epoch, i);
              final selected = DateUtils.isSameDay(day, widget.selected);
              final hasEvents = DemoData.calendarEvents.any(
                (e) => e.includes(day),
              );
              return Semantics(
                label: dateLabel(day),
                selected: selected,
                button: true,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => controller.animateToPage(
                    i,
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        weekdayLabel(day),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(fontSize: 10),
                      ),
                      Text(
                        '${day.day}',
                        maxLines: 1,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: selected
                                  ? colors.onPrimaryContainer
                                  : colors.onSurface,
                            ),
                      ),
                      Container(
                        width: 4,
                        height: 4,
                        margin: const EdgeInsets.only(top: 4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: hasEvents
                              ? colors.primary
                              : Colors.transparent,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class CalendarTileContent extends StatefulWidget {
  const CalendarTileContent({super.key, required this.onOpen});
  final ValueChanged<DateTime> onOpen;
  @override
  State<CalendarTileContent> createState() => _CalendarTileContentState();
}

class _CalendarTileContentState extends State<CalendarTileContent> {
  DateTime selected = dayOnly(DateTime.now());
  @override
  Widget build(BuildContext context) {
    final events = DemoData.calendarEvents
        .where((e) => e.includes(selected))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '${selected.month}月${selected.day}日',
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            Text(
              '${events.length} 项',
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ],
        ),
        const SizedBox(height: 10),
        CalendarDateWheel(
          selected: selected,
          onChanged: (day) => setState(() => selected = day),
        ),
        const SizedBox(height: 12),
        Expanded(
          child: InkWell(
            onTap: () => widget.onOpen(selected),
            child: SizedBox(
              width: double.infinity,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (events.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          '${DateUtils.isSameDay(selected, DateTime.now()) ? '今天' : '${selected.month}月${selected.day}日'}暂无校历事项',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                    for (final event in events.take(2))
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 3,
                              height: 28,
                              margin: const EdgeInsets.only(right: 7),
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    event.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                  Text(
                                    event.category,
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    if (events.length > 2) Text('还有 ${events.length - 2} 项'),
                  ],
                ),
              ),
            ),
          ),
        ),
        Text(
          '演示校历',
          style: Theme.of(context).textTheme.labelSmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key, this.initialDate});
  final DateTime? initialDate;
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  late DateTime selected = dayOnly(widget.initialDate ?? DateTime.now());
  @override
  Widget build(BuildContext context) {
    final events = [...DemoData.calendarEvents]
      ..sort((a, b) => a.start.compareTo(b.start));
    final dayEvents = events.where((e) => e.includes(selected)).toList();
    final months = events
        .map((e) => DateTime(e.start.year, e.start.month))
        .toSet();
    return DetailScaffold(
      title: '校历',
      feature: 'schoolCalendar',
      child: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          Text(
            DemoData.schoolName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          const Text('查看本学期重要安排 · 演示校历'),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Text(
                  dateLabel(selected),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              IconButton(
                tooltip: '选择校历日期',
                icon: const Icon(Icons.calendar_month_rounded),
                onPressed: () async {
                  final day = await showDatePicker(
                    context: context,
                    initialDate: selected,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2100),
                  );
                  if (mounted && day != null) setState(() => selected = day);
                },
              ),
              TextButton(
                onPressed: () =>
                    setState(() => selected = dayOnly(DateTime.now())),
                child: const Text('今天'),
              ),
            ],
          ),
          CalendarDateWheel(
            selected: selected,
            onChanged: (day) => setState(() => selected = day),
          ),
          const SizedBox(height: 14),
          Card.filled(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    DateUtils.isSameDay(selected, DateTime.now())
                        ? 'Today'
                        : '当日事项',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  if (dayEvents.isEmpty) const Text('当天暂无校历事项'),
                  for (final event in dayEvents)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(event.title),
                    ),
                ],
              ),
            ),
          ),
          for (final month in months) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 24, 4, 8),
              child: Text(
                '${month.year}年 ${month.month}月',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final event in events.where(
              (e) => e.start.year == month.year && e.start.month == month.month,
            ))
              Card(
                child: ListTile(
                  leading: SizedBox(
                    width: 42,
                    child: Text(
                      '${event.start.day}',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                  title: Text(event.title),
                  subtitle: Text(
                    '${event.start.month}/${event.start.day} — ${event.end.month}/${event.end.day} · ${event.category}',
                  ),
                  onTap: () => setState(() => selected = event.start),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
