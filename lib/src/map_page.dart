import 'dart:async';
import 'dart:math' as math;

import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'detail_pages.dart';
import 'search_page.dart';
import 'schedule/course_schedule.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.onOpenProfile, this.active = true});
  final bool active;
  final VoidCallback onOpenProfile;
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> with WidgetsBindingObserver {
  static const _amapKey = String.fromEnvironment('AMAP_ANDROID_KEY');
  static const _consentPreference = 'campura.amap.consent.v1';
  AMapController? controller;
  AMapLocation? location;
  bool? consent;
  bool locationAllowed = false;
  final toolKey = GlobalKey();
  Timer? minuteTimer;
  bool foreground = true;
  bool requestingLocation = false;
  String? locationMessage;
  bool centeredOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted && widget.active && foreground) setState(() {});
    });
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => consent = prefs.getBool(_consentPreference) ?? false);
    if (consent == true && _amapKey.isNotEmpty && widget.active) {
      _requestLocation();
    }
  }

  Future<void> _acceptMapPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentPreference, true);
    if (!mounted) return;
    setState(() => consent = true);
    await _requestLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    minuteTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(MapPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active != widget.active) {
      controller = null;
      centeredOnce = false;
      if (widget.active && consent == true && _amapKey.isNotEmpty) {
        _requestLocation();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() {
      foreground = state == AppLifecycleState.resumed;
    });
    if (foreground && widget.active && consent == true && _amapKey.isNotEmpty) {
      _requestLocation();
    }
  }

  Future<void> _requestLocation() async {
    if (requestingLocation ||
        consent != true ||
        _amapKey.isEmpty ||
        !widget.active) {
      return;
    }
    requestingLocation = true;
    try {
      await _requestLocationOnce();
    } catch (_) {
      if (mounted) setState(() => locationMessage = '暂时无法读取定位，请稍后重试');
    } finally {
      requestingLocation = false;
    }
  }

  Future<void> _requestLocationOnce() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      if (mounted) setState(() => locationMessage = '系统定位服务未开启');
      return;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      setState(() => locationMessage = '定位权限未开启，可在系统设置中授权');
      return;
    }
    setState(() {
      locationAllowed = true;
      locationMessage = null;
    });
  }

  void _recenter() {
    if (location != null) {
      controller?.moveCamera(CameraUpdate.newLatLngZoom(location!.latLng, 17));
    } else {
      _requestLocation();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final next = CourseSchedule.demo.nextAfter(DateTime.now());
    final bottom = MediaQuery.paddingOf(context).bottom + 12;
    return SafeArea(
      bottom: false,
      child: Stack(
        children: [
          Positioned.fill(
            child: !widget.active || !foreground
                ? ColoredBox(color: colors.surfaceContainerLow)
                : _mapBody(context),
          ),
          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Row(
              children: [
                Expanded(
                  child: Material(
                    color: colors.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(28),
                    elevation: 3,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(28),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => const SearchPage(),
                        ),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 15,
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.search_rounded),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '搜索促销、商品和商户',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: '个人资料',
                  onPressed: widget.onOpenProfile,
                  icon: const Icon(Icons.person_rounded),
                ),
              ],
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: bottom,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      if (next != null) ...[
                        ActionChip(
                          avatar: const Icon(Icons.menu_book_rounded, size: 18),
                          label: Text(
                            '${_countdown(next.course.startOn(next.day))} · ${next.course.title} · 演示',
                          ),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => CoursePage(initialDate: next.day),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ActionChip(
                          avatar: const Icon(Icons.place_outlined, size: 18),
                          label: Text(next.course.location),
                          onPressed: () => _courseLocation(next),
                        ),
                        const SizedBox(width: 8),
                      ],
                      ActionChip(
                        avatar: const Icon(Icons.shield_outlined, size: 18),
                        label: const Text('平安确认'),
                        onPressed: () => _pending('平安确认'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      key: toolKey,
                      tooltip: '展开实用工具',
                      style: IconButton.styleFrom(
                        minimumSize: const Size(52, 52),
                      ),
                      onPressed: _showTools,
                      icon: const Icon(Icons.menu_rounded),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Card(
                        key: const ValueKey('map-location-card'),
                        margin: EdgeInsets.zero,
                        elevation: 2,
                        color: colors.surfaceContainerHigh,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      location != null
                                          ? '当前位置'
                                          : locationMessage != null
                                          ? '无法获取当前位置'
                                          : '正在确定当前位置…',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleSmall,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      location != null
                                          ? '定位精度约 ±${location!.accuracy.toStringAsFixed(0)} 米'
                                          : locationMessage ?? '首次定位可能需要几秒钟',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelSmall,
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: '回到当前位置',
                                onPressed: _recenter,
                                icon: const Icon(Icons.my_location_rounded),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _countdown(DateTime start) {
    final minutes = math.max(1, start.difference(DateTime.now()).inMinutes);
    if (minutes < 60) return '$minutes 分钟后';
    if (minutes < 1440) return '${minutes ~/ 60} 小时后';
    return '${start.month}/${start.day} ${minuteLabel(start.hour * 60 + start.minute)}';
  }

  Future<void> _courseLocation(CourseOccurrence next) =>
      showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  next.course.location,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                Text('${next.course.title} · ${next.course.timeLabel}'),
                const SizedBox(height: 8),
                const Text('这是演示课程地点。真实教室和校园路线将在校园数据接入后提供。'),
              ],
            ),
          ),
        ),
      );
  Future<void> _pending(String title) => showDialog<void>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(title),
      content: const Text('功能待开放'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('知道了'),
        ),
      ],
    ),
  );

  Future<void> _showTools() async {
    final box = toolKey.currentContext!.findRenderObject()! as RenderBox;
    final origin = box.localToGlobal(Offset.zero);
    final size = MediaQuery.sizeOf(context);
    final top = MediaQuery.paddingOf(context).top;
    final colors = Theme.of(context).colorScheme;
    final selected = await showGeneralDialog<String>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '收起实用工具',
      barrierColor: Colors.black26,
      transitionDuration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
      ),
      transitionBuilder: (context, animation, secondary, child) =>
          FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween(begin: .94, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              alignment: Alignment.bottomLeft,
              child: child,
            ),
          ),
      pageBuilder: (context, _, _) => Stack(
        children: [
          Positioned(
            left: origin.dx,
            bottom: size.height - origin.dy + 8,
            width: math.min(300, size.width - origin.dx - 16),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: math.max(100, origin.dy - top - 16),
              ),
              child: Material(
                color: colors.surfaceContainerHigh,
                elevation: 5,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                        child: Text(
                          '实用工具',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      for (final item in [
                        (Icons.auto_awesome_rounded, '智能推荐', '结合课表安排饮食 · 待开放'),
                        (Icons.history_rounded, '上次购买', '快速回到最近订单 · 待开放'),
                        (Icons.shopping_cart_outlined, '购物车', '查看已加入的商品 · 待开放'),
                        (Icons.shield_outlined, '平安确认', '功能待开放'),
                      ])
                        ListTile(
                          leading: Icon(item.$1, color: colors.primary),
                          title: Text(item.$2),
                          subtitle: Text(item.$3),
                          trailing: const Icon(
                            Icons.north_east_rounded,
                            size: 16,
                          ),
                          onTap: () => Navigator.of(context).pop(item.$2),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: origin.dx,
            top: origin.dy,
            child: IconButton.filledTonal(
              tooltip: '收起实用工具',
              style: IconButton.styleFrom(minimumSize: const Size(52, 52)),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
    if (mounted && selected != null) await _pending(selected);
  }

  Widget _mapBody(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    if (consent == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_amapKey.isEmpty) {
      return _MapPlaceholder(
        icon: Icons.map_rounded,
        title: '高德地图待配置',
        message: '地图页、校园搜索和工具已就绪。加入你申请的 Android Key 后即可显示高德底图。',
        actionLabel: null,
        onAction: null,
      );
    }
    if (consent == false) {
      return _MapPlaceholder(
        icon: Icons.privacy_tip_rounded,
        title: '使用高德地图前',
        message: '地图展示与定位由高德地图 SDK 提供。使用时会向高德提供设备、网络和位置信息。请先阅读高德隐私政策；同意后才会初始化地图和申请定位权限。',
        actionLabel: '同意并打开地图',
        onAction: _acceptMapPrivacy,
        footer: TextButton(
          onPressed: () => launchUrl(
            Uri.parse('https://lbs.amap.com/pages/privacy/'),
            mode: LaunchMode.externalApplication,
          ),
          child: const Text('查看高德隐私政策'),
        ),
      );
    }
    return AMapWidget(
      apiKey: const AMapApiKey(androidKey: _amapKey),
      privacyStatement: const AMapPrivacyStatement(
        hasContains: true,
        hasShow: true,
        hasAgree: true,
      ),
      initialCameraPosition: const CameraPosition(
        target: LatLng(30.315, 114.340),
        zoom: 14,
      ),
      myLocationStyleOptions: MyLocationStyleOptions(
        locationAllowed,
        circleFillColor: colors.primary.withValues(alpha: .12),
        circleStrokeColor: colors.primary,
      ),
      compassEnabled: true,
      scaleEnabled: true,
      onMapCreated: (mapController) => controller = mapController,
      onLocationChanged: (newLocation) {
        setState(() => location = newLocation);
        if (!centeredOnce) {
          centeredOnce = true;
          controller?.moveCamera(
            CameraUpdate.newLatLngZoom(newLocation.latLng, 17),
          );
        }
      },
    );
  }
}

class _MapPlaceholder extends StatelessWidget {
  const _MapPlaceholder({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
    this.footer,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Container(
      color: colors.surfaceContainerLow,
      alignment: Alignment.center,
      padding: const EdgeInsets.fromLTRB(20, 80, 20, 210),
      child: SingleChildScrollView(
        child: Card(
          color: colors.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 64, color: colors.primary),
                const SizedBox(height: 18),
                Text(title, style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 18),
                ?footer,
                if (actionLabel != null)
                  FilledButton(onPressed: onAction, child: Text(actionLabel!)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
