import 'package:amap_flutter_base/amap_flutter_base.dart';
import 'package:amap_flutter_map/amap_flutter_map.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'demo_data.dart';
import 'detail_pages.dart';
import 'search_page.dart';

class MapPage extends StatefulWidget {
  const MapPage({super.key, required this.onOpenProfile});
  final VoidCallback onOpenProfile;
  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  static const _amapKey = String.fromEnvironment('AMAP_ANDROID_KEY');
  static const _consentPreference = 'campura.amap.consent.v1';
  AMapController? controller;
  AMapLocation? location;
  bool? consent;
  bool locationAllowed = false;
  bool toolsExpanded = false;
  String? locationMessage;
  bool centeredOnce = false;

  @override
  void initState() {
    super.initState();
    _loadConsent();
  }

  Future<void> _loadConsent() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => consent = prefs.getBool(_consentPreference) ?? false);
    if (consent == true && _amapKey.isNotEmpty) _requestLocation();
  }

  Future<void> _acceptMapPrivacy() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_consentPreference, true);
    if (!mounted) return;
    setState(() => consent = true);
    await _requestLocation();
  }

  Future<void> _requestLocation() async {
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
    return SafeArea(
      child: Stack(
        children: [
          Positioned.fill(child: _mapBody(context)),
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
                            Expanded(child: Text('搜索促销、商品和商户')),
                            Icon(Icons.tune_rounded),
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
            bottom: 100,
            child: Column(
              children: [
                Card(
                  elevation: 2,
                  color: colors.surfaceContainerHigh,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.location_on_rounded),
                        const SizedBox(width: 9),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('当前位置'),
                              Text(
                                location != null
                                    ? '定位精度约 ${location!.accuracy.toStringAsFixed(0)} 米'
                                    : locationMessage ??
                                          (_amapKey.isEmpty
                                              ? '等待高德 Android Key'
                                              : '等待定位…'),
                                style: Theme.of(context).textTheme.bodySmall,
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
                const SizedBox(height: 7),
                Card(
                  elevation: 2,
                  color: colors.surfaceContainerHigh,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.explore_rounded),
                        title: const Text('校园工具'),
                        subtitle: const Text('课程状态 · 附近商户'),
                        trailing: Icon(
                          toolsExpanded
                              ? Icons.expand_more_rounded
                              : Icons.expand_less_rounded,
                        ),
                        onTap: () =>
                            setState(() => toolsExpanded = !toolsExpanded),
                      ),
                      if (toolsExpanded) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.calendar_today_rounded),
                          title: Text(
                            '今天 ${DemoData.coursesOn(DateTime.now()).length} 节课',
                          ),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const CoursePage(),
                            ),
                          ),
                        ),
                        ListTile(
                          leading: const Icon(Icons.storefront_rounded),
                          title: const Text('校园商户'),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ShopsPage(),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
      padding: const EdgeInsets.fromLTRB(28, 0, 28, 105),
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
    );
  }
}
