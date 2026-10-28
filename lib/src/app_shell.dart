import 'package:flutter/material.dart';

import 'demo_data.dart';
import 'announcement_feed.dart';
import 'home_page.dart';
import 'map_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, this.studentToken, this.apiBaseUri});
  final String? studentToken;
  final Uri? apiBaseUri;

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int selected = 0;
  bool mapVisited = false;
  final homeScroll = ScrollController();
  AnnouncementFeed? _announcementFeed;

  @override
  void initState() {
    super.initState();
    if (widget.studentToken != null && widget.apiBaseUri != null) {
      _announcementFeed = AnnouncementFeed(baseUri: widget.apiBaseUri!);
    }
  }

  @override
  void dispose() {
    homeScroll.dispose();
    _announcementFeed?.dispose();
    super.dispose();
  }

  void _openProfile() => showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) {
      final colors = Theme.of(context).colorScheme;
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: colors.primaryContainer,
                child: Icon(
                  Icons.person_rounded,
                  size: 38,
                  color: colors.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '${DemoData.studentName}同学',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 4),
              const Text('本地演示身份 · 尚未接入登录'),
              const SizedBox(height: 20),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.school_rounded),
                title: Text(DemoData.schoolName),
                subtitle: Text('学校和学生资料将在登录接入后显示'),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.palette_rounded),
                title: const Text('跟随系统配色'),
                subtitle: const Text('Android 12 及以上使用壁纸动态取色'),
                trailing: Icon(
                  Icons.check_circle_rounded,
                  color: colors.primary,
                ),
              ),
              const ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.info_outline_rounded),
                title: Text('演示模式'),
                subtitle: Text('课程、通知、商户与校历均为本地示例内容'),
              ),
            ],
          ),
        ),
      );
    },
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: IndexedStack(
        index: selected,
        children: [
          HomePage(
            onOpenProfile: _openProfile,
            scrollController: homeScroll,
            announcementFeed: _announcementFeed,
            studentToken: widget.studentToken,
          ),
          if (mapVisited)
            MapPage(onOpenProfile: _openProfile, active: selected == 1)
          else
            const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Material(
          key: const ValueKey('floating-tab-bar'),
          elevation: 3,
          shadowColor: colors.shadow.withValues(alpha: .24),
          color: colors.surfaceContainerHigh.withValues(alpha: .96),
          shape: const StadiumBorder(),
          clipBehavior: Clip.antiAlias,
          child: NavigationBar(
            height: 72,
            backgroundColor: Colors.transparent,
            indicatorColor: colors.secondaryContainer,
            selectedIndex: selected,
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            onDestinationSelected: (value) {
              if (value == selected && value == 0 && homeScroll.hasClients) {
                homeScroll.animateTo(
                  0,
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                );
              }
              setState(() {
                selected = value;
                if (value == 1) mapVisited = true;
              });
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: '仪表盘',
              ),
              NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: '地图',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
