import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'demo_data.dart';
import 'detail_pages.dart';
import 'announcement_feed.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenProfile,
    this.announcementFeed,
    this.studentToken,
  });
  final VoidCallback onOpenProfile;
  final AnnouncementFeed? announcementFeed;
  final String? studentToken;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool tomorrow = false;
  int adIndex = 0;
  bool showWeather = true;
  late List<CampusAnnouncement> announcements;
  String? aiSummary;
  bool announcementLoadFailed = false;

  @override
  void initState() {
    super.initState();
    announcements = widget.studentToken == null
        ? DemoData.announcements
        : <CampusAnnouncement>[];
    _loadAnnouncements();
  }

  Future<void> _loadAnnouncements() async {
    final token = widget.studentToken;
    final feed = widget.announcementFeed;
    if (token == null || token.isEmpty || feed == null) return;
    try {
      final result = await feed.load(token);
      if (!mounted) return;
      setState(() {
        announcements = result.announcements;
        aiSummary = result.summary;
        announcementLoadFailed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        aiSummary = null;
        announcementLoadFailed = true;
      });
    }
  }

  DateTime get shownDay => DateTime.now().add(Duration(days: tomorrow ? 1 : 0));

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final greeting = switch (now.hour) {
      < 4 => '深夜了，晚安',
      < 7 => '清晨，早安',
      < 11 => '早上好，',
      < 14 => '中午好，',
      < 18 => '下午好，',
      _ => '晚上好，',
    };
    return SafeArea(
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        greeting,
                        style: Theme.of(context).textTheme.headlineLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton.filledTonal(
                      tooltip: '个人资料',
                      onPressed: widget.onOpenProfile,
                      icon: const Icon(Icons.person_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 12,
                  runSpacing: 10,
                  children: [
                    Text(
                      '${DemoData.studentName}同学',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    ActionChip(
                      avatar: Icon(
                        showWeather
                            ? Icons.water_drop_rounded
                            : Icons.location_on_rounded,
                        size: 18,
                        color: colors.onSecondaryContainer,
                      ),
                      label: Text(
                        showWeather
                            ? '${DemoData.weatherTemperature}° · 小雨'
                            : DemoData.weatherPlace,
                      ),
                      onPressed: () =>
                          setState(() => showWeather = !showWeather),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                _announcementBanner(context),
                const SizedBox(height: 16),
                _largeAds(context),
                const SizedBox(height: 27),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 12) / 2;
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: width,
                          child: Column(
                            children: [
                              SizedBox(
                                height: 42,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    'Today和精选',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _courseTile(context),
                              const SizedBox(height: 12),
                              _smallAdsTile(context),
                              const SizedBox(height: 12),
                              _promotionsTile(context),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        SizedBox(
                          width: width,
                          child: Column(
                            children: [
                              _toolboxTile(context, width),
                              const SizedBox(height: 12),
                              _calendarTile(context),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '演示内容 · 登录和校园数据接入后自动替换',
                    style: Theme.of(context).textTheme.labelSmall
                        ?.copyWith(color: colors.onSurfaceVariant),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _announcementBanner(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final importantCount = announcements.where((a) => a.type == 2).length;
    final shortNotices = announcements.where((a) => a.type != 2).toList();
    return SizedBox(
      height: 88,
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
                onTap: importantCount == 0
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => MarkdownAnnouncementsPage(
                            announcements: announcements,
                          ),
                        ),
                      ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.priority_high_rounded,
                        size: 20,
                        color: colors.onErrorContainer,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$importantCount',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ],
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
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) =>
                        AnnouncementsPage(announcements: announcements),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(
                        Icons.campaign_rounded,
                        color: colors.onTertiaryContainer,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              shortNotices.isEmpty ? '校园通知' : '短通知',
                              style: Theme.of(context).textTheme.labelLarge,
                            ),
                            Text(
                              announcementLoadFailed
                                  ? '通知加载失败'
                                  : aiSummary ??
                                        (widget.studentToken == null
                                            ? '摘要不可用 · 演示通知'
                                            : '摘要不可用'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _largeAds(BuildContext context) => Column(
    children: [
      AspectRatio(
        aspectRatio: 3,
        child: PageView.builder(
          itemCount: DemoData.largeAdAssets.length,
          onPageChanged: (value) => setState(() => adIndex = value),
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Material(
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const AdvertisementPage(),
                    ),
                  ),
                  child: Image.asset(
                    DemoData.largeAdAssets[index],
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 7),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          DemoData.largeAdAssets.length,
          (index) => Container(
            width: index == adIndex ? 17 : 6,
            height: 6,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: index == adIndex
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
      ),
    ],
  );

  Widget _courseTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final courses = DemoData.coursesOn(shownDay);
    return DashboardTile(
      title: '课程表',
      icon: Icons.calendar_month_rounded,
      color: colors.primaryContainer,
      height: 222,
      openBuilder: (_) => const CoursePage(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _dayArrow(
            Icons.chevron_left_rounded,
            !tomorrow,
            () => setState(() => tomorrow = false),
          ),
          Text(
            tomorrow ? '明' : '今',
            style: Theme.of(context).textTheme.labelSmall,
          ),
          _dayArrow(
            Icons.chevron_right_rounded,
            tomorrow,
            () => setState(() => tomorrow = true),
          ),
        ],
      ),
      child: courses.isEmpty
          ? const Text('当天暂无课程')
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: courses
                  .take(2)
                  .map(
                    (course) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${course.timeLabel} · ${course.location}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            course.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }

  Widget _dayArrow(IconData icon, bool disabled, VoidCallback onPressed) =>
      IconButton(
        onPressed: disabled ? null : onPressed,
        icon: Icon(icon, size: 17),
        visualDensity: VisualDensity.compact,
        constraints: const BoxConstraints(minWidth: 25, minHeight: 30),
        padding: EdgeInsets.zero,
      );

  Widget _smallAdsTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DashboardTile(
      title: '',
      icon: null,
      color: colors.tertiaryContainer,
      height: 176,
      showHeader: false,
      openBuilder: (_) => const AdvertisementPage(),
      child: SizedBox.expand(
        child: PageView.builder(
          controller: PageController(viewportFraction: .88),
          itemCount: DemoData.largeAdAssets.length,
          itemBuilder: (context, index) => Padding(
            padding: const EdgeInsets.only(right: 6, bottom: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                DemoData.largeAdAssets[index],
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _promotionsTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DashboardTile(
      title: '最近促销',
      icon: Icons.sell_rounded,
      color: colors.secondaryContainer,
      height: 190,
      openBuilder: (_) => const PromotionsPage(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: DemoData.promotions
            .take(2)
            .map(
              (sale) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const Icon(Icons.local_offer_outlined, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        sale.rule,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _toolboxTile(BuildContext context, double width) {
    final colors = Theme.of(context).colorScheme;
    return DashboardTile(
      title: '工具箱',
      icon: Icons.grid_view_rounded,
      color: colors.surfaceContainerHigh,
      height: width,
      openBuilder: null,
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ToolLabel(Icons.accessible_forward_rounded, '找最近的卫生间'),
          SizedBox(height: 10),
          _ToolLabel(Icons.directions_run_rounded, '跑腿'),
          SizedBox(height: 10),
          _ToolLabel(Icons.inventory_2_outlined, '快递外卖'),
        ],
      ),
    );
  }

  Widget _calendarTile(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DashboardTile(
      title: '校历',
      icon: Icons.event_note_rounded,
      color: colors.surfaceContainerHighest,
      height: 378,
      openBuilder: (_) => const CalendarPage(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DateTime.now().month}月',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 14),
          ...DemoData.calendarEvents
              .take(3)
              .map(
                (event) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${event.start.month}/${event.start.day}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                      Text(
                        event.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

class DashboardTile extends StatelessWidget {
  const DashboardTile({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.height,
    required this.child,
    required this.openBuilder,
    this.trailing,
    this.showHeader = true,
  });
  final String title;
  final IconData? icon;
  final Color color;
  final double height;
  final Widget child;
  final WidgetBuilder? openBuilder;
  final Widget? trailing;
  final bool showHeader;

  @override
  Widget build(BuildContext context) => openBuilder == null
      ? _closed(context, null)
      : OpenContainer<void>(
          transitionType: ContainerTransitionType.fadeThrough,
          transitionDuration: const Duration(milliseconds: 430),
          closedElevation: 0,
          openElevation: 0,
          closedColor: color,
          openColor: Theme.of(context).colorScheme.surface,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          openBuilder: (context, _) => openBuilder!(context),
          closedBuilder: (context, open) => _closed(context, open),
        );

  Widget _closed(BuildContext context, VoidCallback? open) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    child: SizedBox(
      height: height,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Row(
                  children: [
                    if (icon != null) ...[
                      Icon(icon, size: 21),
                      const SizedBox(width: 5),
                    ],
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    if (open != null)
                      const Icon(Icons.north_east_rounded, size: 16),
                  ],
                ),
                if (trailing != null) ...[const SizedBox(height: 7), trailing!],
                const SizedBox(height: 12),
              ],
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ToolLabel extends StatelessWidget {
  const _ToolLabel(this.icon, this.label);
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Icon(icon, size: 18),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall,
        ),
      ),
    ],
  );
}
