import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../announcement_controller.dart';
import '../demo_data.dart';
import '../schedule/course_schedule.dart';
import 'detail_scaffold.dart';

String announcementDate(CampusAnnouncement item) {
  if (item.startTime == null && item.endTime == null) return '有效期不限';
  return '${item.startTime == null ? '即日起' : dateLabel(item.startTime!.toLocal())} — ${item.endTime == null ? '长期有效' : dateLabel(item.endTime!.toLocal())}';
}

String announcementRemaining(CampusAnnouncement item) {
  if (item.endTime == null) return '长期有效';
  final minutes = item.endTime!.difference(DateTime.now()).inMinutes;
  if (minutes < 0) return '已结束';
  if (minutes < 60) return '即将结束';
  if (minutes < 1440) return '剩余 ${minutes ~/ 60} 小时';
  return '剩余 ${(minutes / 1440).ceil()} 天';
}

class AnnouncementBanner extends StatefulWidget {
  const AnnouncementBanner({super.key, required this.controller});
  final AnnouncementController controller;
  @override
  State<AnnouncementBanner> createState() => _AnnouncementBannerState();
}

class _AnnouncementBannerState extends State<AnnouncementBanner> {
  bool expanded = false, showAll = false;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.controller,
    builder: (context, _) {
      final controller = widget.controller;
      final colors = Theme.of(context).colorScheme;
      final rowHeight =
          88.0 +
          (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 22) * 3;
      return Column(
        children: [
          SizedBox(
            height: rowHeight,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: 76,
                  child: Card(
                    key: const ValueKey('important-notice-entry'),
                    margin: EdgeInsets.zero,
                    color: colors.errorContainer,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              MarkdownAnnouncementsPage(controller: controller),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              Icon(
                                Icons.priority_high_rounded,
                                size: 20,
                                color: colors.onErrorContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${controller.important.length}',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(color: colors.onErrorContainer),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Card(
                    key: const ValueKey('short-notice-entry'),
                    margin: EdgeInsets.zero,
                    color: colors.tertiaryContainer,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(24),
                      onTap: () => setState(() {
                        expanded = !expanded;
                        if (!expanded) showAll = false;
                      }),
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Row(
                          children: [
                            Icon(
                              Icons.campaign_rounded,
                              color: colors.onTertiaryContainer,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    controller.loadFailed ? '通知加载失败' : '校园通知',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelLarge,
                                  ),
                                  Text(
                                    controller.summaryLabel,
                                    maxLines: expanded ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedRotation(
                              turns: expanded ? .25 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: const Icon(
                                Icons.chevron_right_rounded,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 240),
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Card.filled(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            if (showAll) ...[
                              if (controller.short.isEmpty)
                                const Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Text('暂无新的短通知'),
                                ),
                              for (final item in controller.short)
                                _ShortNoticeRow(
                                  item: item,
                                  controller: controller,
                                ),
                            ],
                            Row(
                              children: [
                                Expanded(
                                  child: TextButton(
                                    onPressed: () =>
                                        setState(() => showAll = !showAll),
                                    child: Text(showAll ? '收起' : '查看完整信息'),
                                  ),
                                ),
                                IconButton(
                                  tooltip: '打开短通知列表',
                                  onPressed: () => Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => AnnouncementsPage(
                                        controller: controller,
                                      ),
                                    ),
                                  ),
                                  icon: const Icon(Icons.north_east_rounded),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      );
    },
  );
}

class _ShortNoticeRow extends StatelessWidget {
  const _ShortNoticeRow({required this.item, this.controller});
  final CampusAnnouncement item;
  final AnnouncementController? controller;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 4),
    leading: Icon(
      item.type == 1
          ? Icons.warning_amber_rounded
          : Icons.notifications_none_rounded,
      size: 20,
    ),
    title: Text(item.content, maxLines: 2, overflow: TextOverflow.ellipsis),
    subtitle: Text(
      '${announcementDate(item)} · ${announcementRemaining(item)}',
    ),
    onTap: () => Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _ShortNoticePage(item: item, controller: controller),
      ),
    ),
  );
}

class _ShortNoticePage extends StatelessWidget {
  const _ShortNoticePage({required this.item, this.controller});
  final CampusAnnouncement item;
  final AnnouncementController? controller;
  @override
  Widget build(BuildContext context) {
    Widget body() {
      final current = controller == null
          ? item
          : controller!.notices.where((n) => n.id == item.id).firstOrNull;
      return DetailScaffold(
        title: '${item.category}通知',
        child: current == null
            ? const Center(child: Text('此通知已不在有效列表中'))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcementDate(current),
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 16),
                    SelectableText(
                      current.content,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
      );
    }

    return controller == null
        ? body()
        : ListenableBuilder(listenable: controller!, builder: (_, _) => body());
  }
}

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, this.announcements, this.controller});
  final List<CampusAnnouncement>? announcements;
  final AnnouncementController? controller;
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  int? filter;
  @override
  Widget build(BuildContext context) {
    Widget page() {
      final items =
          (widget.controller?.short ??
                  widget.announcements ??
                  DemoData.announcements)
              .where(
                (n) =>
                    n.type != 2 &&
                    n.isActive(DateTime.now()) &&
                    (filter == null || filter == n.type),
              );
      return DetailScaffold(
        title: '短通知',
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              children: [
                for (final type in <int?>[null, 1, 0])
                  ChoiceChip(
                    label: Text(
                      type == null
                          ? '全部'
                          : type == 1
                          ? '紧急'
                          : '日常',
                    ),
                    selected: type == filter,
                    onSelected: (_) => setState(() => filter = type),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Padding(padding: EdgeInsets.all(24), child: Text('暂无短通知')),
            for (final item in items)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: _ShortNoticeRow(
                    item: item,
                    controller: widget.controller,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return widget.controller == null
        ? page()
        : ListenableBuilder(
            listenable: widget.controller!,
            builder: (_, _) => page(),
          );
  }
}

class MarkdownAnnouncementsPage extends StatefulWidget {
  const MarkdownAnnouncementsPage({
    super.key,
    this.announcements,
    this.controller,
  });
  final List<CampusAnnouncement>? announcements;
  final AnnouncementController? controller;
  @override
  State<MarkdownAnnouncementsPage> createState() =>
      _MarkdownAnnouncementsPageState();
}

class _MarkdownAnnouncementsPageState extends State<MarkdownAnnouncementsPage> {
  Timer? timer;
  @override
  void initState() {
    super.initState();
    if (widget.controller == null &&
        (widget.announcements ?? []).any((n) => n.endTime != null)) {
      timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget page() {
      final items =
          widget.controller?.important ??
          (widget.announcements ?? DemoData.announcements)
              .where((n) => n.type == 2 && n.isActive(DateTime.now()))
              .toList();
      return DetailScaffold(
        title: '重要通知',
        child: items.isEmpty
            ? const Center(child: Text('暂无重要通知'))
            : ListView.separated(
                padding: const EdgeInsets.all(20),
                itemCount: items.length,
                separatorBuilder: (_, _) => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 18),
                  child: Divider(),
                ),
                itemBuilder: (context, i) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      announcementDate(items[i]),
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 12),
                    MarkdownBody(data: items[i].content, selectable: true),
                  ],
                ),
              ),
      );
    }

    return widget.controller == null
        ? page()
        : ListenableBuilder(
            listenable: widget.controller!,
            builder: (_, _) => page(),
          );
  }
}
