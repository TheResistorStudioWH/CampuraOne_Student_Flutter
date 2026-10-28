import 'dart:async';

import 'package:animations/animations.dart';
import 'package:flutter/material.dart';

import 'announcement_controller.dart';
import 'announcement_feed.dart';
import 'calendar/calendar_widgets.dart';
import 'demo_data.dart';
import 'detail_pages.dart';
import 'schedule/course_schedule.dart';
import 'widgets/advertisement_deck.dart';
import 'widgets/announcements.dart';

class HomePage extends StatefulWidget {
  const HomePage({
    super.key,
    required this.onOpenProfile,
    this.announcementFeed,
    this.studentToken,
    this.scrollController,
  });
  final VoidCallback onOpenProfile;
  final AnnouncementFeed? announcementFeed;
  final String? studentToken;
  final ScrollController? scrollController;
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late AnnouncementController notices;
  late final ScrollController scroll =
      widget.scrollController ?? ScrollController();
  final adPages = PageController();
  Timer? weatherTimer;
  bool tomorrow = false, showWeather = false, pinned = false, hot = false;
  int adIndex = 0, calendarRevision = 0;
  List<CampusPromotion> sales = [...DemoData.promotions]..shuffle();
  @override
  void initState() {
    super.initState();
    notices = AnnouncementController(
      feed: widget.announcementFeed,
      token: widget.studentToken,
    )..start();
    scroll.addListener(_scrolled);
    weatherTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => showWeather = true);
    });
  }

  @override
  void didUpdateWidget(HomePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.studentToken != widget.studentToken ||
        oldWidget.announcementFeed != widget.announcementFeed) {
      notices.dispose();
      notices = AnnouncementController(
        feed: widget.announcementFeed,
        token: widget.studentToken,
      )..start();
    }
  }

  void _scrolled() {
    final value = scroll.offset >= 96;
    if (pinned != value) setState(() => pinned = value);
  }

  @override
  void dispose() {
    weatherTimer?.cancel();
    notices.dispose();
    adPages.dispose();
    scroll.removeListener(_scrolled);
    if (widget.scrollController == null) scroll.dispose();
    super.dispose();
  }

  DateTime get shownDay => dayOffset(DateTime.now(), tomorrow ? 1 : 0);
  void _open(Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  void _setMode(bool value) => setState(() {
    hot = value;
    sales = [...DemoData.promotions];
    if (hot) {
      sales.sort(
        (a, b) => (a.endTime ?? DateTime(9999)).compareTo(
          b.endTime ?? DateTime(9999),
        ),
      );
    } else {
      sales.shuffle();
    }
  });
  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final greeting = switch (DateTime.now().hour) {
      < 4 || 23 => '深夜了，晚安',
      < 7 => '清晨，早安',
      < 10 => '早上好！',
      < 12 => '上午好，',
      < 15 => '中午好，',
      < 19 => '下午好，',
      _ => '晚上好，',
    };
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          RefreshIndicator(
            onRefresh: notices.refresh,
            child: CustomScrollView(
              controller: scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverPadding(
                  padding: EdgeInsets.fromLTRB(
                    18,
                    12,
                    18,
                    MediaQuery.paddingOf(context).bottom + 24,
                  ),
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
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${DemoData.studentName}同学',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                          ),
                          Flexible(
                            child: ActionChip(
                              avatar: Icon(
                                showWeather
                                    ? Icons.water_drop_rounded
                                    : Icons.location_on_rounded,
                                size: 18,
                              ),
                              label: Text(
                                showWeather
                                    ? '${DemoData.weatherTemperature}° · 小雨'
                                    : DemoData.weatherPlace,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onPressed: () {
                                weatherTimer?.cancel();
                                setState(() => showWeather = !showWeather);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      AnnouncementBanner(controller: notices),
                      const SizedBox(height: 16),
                      _largeAds(),
                      const SizedBox(height: 24),
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final width = (constraints.maxWidth - 12) / 2;
                          final fontScale =
                              MediaQuery.textScalerOf(context).scale(14) / 14;
                          final tile = width.clamp(170.0, 260.0);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  children: [
                                    SizedBox(
                                      height: 44,
                                      child: Align(
                                        alignment: Alignment.centerLeft,
                                        child: Text(
                                          'Today和精选',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleLarge
                                              ?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    _courseTile(tile + (fontScale - 1) * 45),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      height: tile,
                                      child: const AdvertisementDeck(),
                                    ),
                                    const SizedBox(height: 14),
                                    _promotionsTile(tile * 1.45),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  children: [
                                    _toolboxTile(width),
                                    const SizedBox(height: 12),
                                    _calendarTile(
                                      tile * 2 + 12 + (fontScale - 1) * 80,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      Text(
                        '本地演示 · 学生身份、课程、通知、天气及校园内容均为示例',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ]),
                  ),
                ),
              ],
            ),
          ),
          IgnorePointer(
            ignoring: !pinned,
            child: AnimatedSlide(
              offset: pinned ? Offset.zero : const Offset(0, -1),
              duration: const Duration(milliseconds: 220),
              child: AnimatedOpacity(
                opacity: pinned ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Material(
                  elevation: 2,
                  color: colors.surfaceContainer,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
                    child: ListenableBuilder(
                      listenable: notices,
                      builder: (context, _) => Row(
                        children: [
                          IconButton.filledTonal(
                            tooltip: '重要通知',
                            onPressed: () => _open(
                              MarkdownAnnouncementsPage(controller: notices),
                            ),
                            icon: Badge(
                              label: Text('${notices.important.length}'),
                              child: const Icon(Icons.priority_high_rounded),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: InkWell(
                              onTap: () =>
                                  _open(AnnouncementsPage(controller: notices)),
                              child: Row(
                                children: [
                                  const Icon(Icons.campaign_outlined, size: 20),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      notices.summaryLabel,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '回到顶部',
                            onPressed: () => scroll.animateTo(
                              0,
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeOutCubic,
                            ),
                            icon: const Icon(Icons.vertical_align_top_rounded),
                          ),
                          IconButton(
                            tooltip: '个人资料',
                            onPressed: widget.onOpenProfile,
                            icon: const Icon(Icons.person_rounded),
                          ),
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
  }

  Widget _largeAds() => Column(
    children: [
      AspectRatio(
        aspectRatio: 3,
        child: PageView.builder(
          controller: adPages,
          itemCount: DemoData.largeAdAssets.length,
          onPageChanged: (i) => setState(() => adIndex = i),
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: GestureDetector(
                onTap: () => _open(AdvertisementPage(initialIndex: i)),
                child: Image.asset(
                  DemoData.largeAdAssets[i],
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        ),
      ),
      const SizedBox(height: 8),
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < DemoData.largeAdAssets.length; i++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: adIndex == i ? 17 : 6,
              height: 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: adIndex == i
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
        ],
      ),
    ],
  );

  Widget _courseTile(double height) {
    final courses = CourseSchedule.demo.on(shownDay);
    return DashboardTile(
      title: '日程表',
      icon: Icons.calendar_month_rounded,
      color: Theme.of(context).colorScheme.primaryContainer,
      height: height,
      openBuilder: (_) => const CoursePage(),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final value in [false, true])
            _MiniToggle(
              label: value ? '明' : '今',
              selected: tomorrow == value,
              onTap: () => setState(() => tomorrow = value),
            ),
        ],
      ),
      child: courses.isEmpty
          ? const Center(child: Text('当天暂无课程'))
          : SingleChildScrollView(
              child: CourseDayTimeline(
                courses: courses,
                compact: true,
                onOpen: (_) => _open(const CoursePage()),
              ),
            ),
    );
  }

  Widget _toolboxTile(double width) => DashboardTile(
    title: '工具箱',
    icon: Icons.grid_view_rounded,
    color: Theme.of(context).colorScheme.surfaceContainerHigh,
    height: width,
    openBuilder: null,
    child: SingleChildScrollView(
      child: Column(
        children: [
          for (final item in [
            (Icons.wc_rounded, '找最近的卫生间'),
            (Icons.directions_run_rounded, '跑腿'),
            (Icons.inventory_2_outlined, '快递外卖'),
          ])
            Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: Row(
                children: [
                  Icon(item.$1, size: 18),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      item.$2,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
  Widget _calendarTile(double height) => DashboardTile(
    title: '校历',
    icon: Icons.event_note_rounded,
    color: Theme.of(context).colorScheme.surfaceContainerHighest,
    height: height,
    openBuilder: (_) => const CalendarPage(),
    trailing: IconButton(
      tooltip: '重置校历日期',
      onPressed: () => setState(() => calendarRevision++),
      constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.refresh_rounded, size: 18),
    ),
    child: CalendarTileContent(
      key: ValueKey(calendarRevision),
      onOpen: (day) => _open(CalendarPage(initialDate: day)),
    ),
  );
  Widget _promotionsTile(double height) => DashboardTile(
    title: '最近促销',
    icon: Icons.sell_rounded,
    color: Theme.of(context).colorScheme.secondaryContainer,
    height: height,
    openBuilder: (_) => PromotionsPage(initialHot: hot),
    trailing: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MiniToggle(
          icon: Icons.local_fire_department_rounded,
          label: '热榜',
          selected: hot,
          onTap: () => _setMode(true),
        ),
        _MiniToggle(
          icon: Icons.shuffle_rounded,
          label: '随机',
          selected: !hot,
          onTap: () => _setMode(false),
        ),
      ],
    ),
    child: SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final (index, sale) in sales.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 15),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 20,
                    child: hot
                        ? Text(
                            '${index + 1}',
                            style: Theme.of(context).textTheme.titleSmall,
                          )
                        : const Icon(Icons.local_offer_outlined, size: 16),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          sale.rule,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                        Text(
                          sale.remainingLabel,
                          style: Theme.of(context).textTheme.labelSmall,
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

class _MiniToggle extends StatelessWidget {
  const _MiniToggle({
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: label,
    child: Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          width: 28,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? Theme.of(context).colorScheme.surface.withValues(alpha: .8)
                : null,
            borderRadius: BorderRadius.circular(9),
          ),
          child: icon == null
              ? Text(label, style: Theme.of(context).textTheme.labelSmall)
              : Icon(icon, size: 16),
        ),
      ),
    ),
  );
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
  });
  final String title;
  final IconData? icon;
  final Color color;
  final double height;
  final Widget child;
  final WidgetBuilder? openBuilder;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => openBuilder == null
      ? _closed(context, null)
      : OpenContainer<void>(
          transitionType: ContainerTransitionType.fadeThrough,
          transitionDuration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 400,
          ),
          closedElevation: 0,
          openElevation: 0,
          closedColor: color,
          openColor: Theme.of(context).colorScheme.surface,
          closedShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          tappable: false,
          openBuilder: (context, _) => openBuilder!(context),
          closedBuilder: (context, open) => _closed(context, open),
        );
  Widget _closed(BuildContext context, VoidCallback? open) => Material(
    color: color,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: SizedBox(
      height: height,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: 19),
                    const SizedBox(width: 4),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  if (trailing != null)
                    trailing!
                  else if (open != null)
                    const Icon(Icons.north_east_rounded, size: 16),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(child: child),
            ],
          ),
        ),
      ),
    ),
  );
}
