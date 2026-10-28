import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TileNotificationPreference {
  off('关闭通知', '不再接收此磁贴的通知', Icons.notifications_off_outlined),
  muteToday('今天内静音', '今天结束后自动打开', Icons.snooze_rounded),
  muteWeek('一周内静音', '七天后自动打开', Icons.event_busy_rounded),
  on('打开', '接收此磁贴的通知', Icons.notifications_active_outlined);

  const TileNotificationPreference(this.title, this.description, this.icon);
  final String title, description;
  final IconData icon;
}

class TileNotificationSettings {
  const TileNotificationSettings(this.preferences, this.feature);
  final SharedPreferences preferences;
  final String feature;
  String get _key => 'campura.dashboard.$feature.notification';
  TileNotificationPreference read({DateTime? at}) {
    final now = at ?? DateTime.now();
    final saved =
        TileNotificationPreference.values
            .where((e) => e.name == preferences.getString(_key))
            .firstOrNull ??
        TileNotificationPreference.on;
    final until = preferences.getInt('$_key.until');
    if ((saved == TileNotificationPreference.muteToday ||
            saved == TileNotificationPreference.muteWeek) &&
        (until == null || until <= now.millisecondsSinceEpoch)) {
      return TileNotificationPreference.on;
    }
    return saved;
  }

  Future<void> set(TileNotificationPreference value, {DateTime? at}) async {
    final now = at ?? DateTime.now();
    final until = switch (value) {
      TileNotificationPreference.muteToday => DateTime(
        now.year,
        now.month,
        now.day + 1,
      ),
      TileNotificationPreference.muteWeek => DateTime(
        now.year,
        now.month,
        now.day + 7,
        now.hour,
        now.minute,
        now.second,
      ),
      _ => null,
    };
    if (until == null) {
      await preferences.remove('$_key.until');
    } else {
      await preferences.setInt('$_key.until', until.millisecondsSinceEpoch);
    }
    await preferences.setString(_key, value.name);
  }
}

Future<void> showTileSettings(
  BuildContext context,
  String feature,
  String title,
) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => _SettingsSheet(feature: feature, title: title),
);

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet({required this.feature, required this.title});
  final String feature, title;
  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  TileNotificationSettings? settings;
  TileNotificationPreference value = TileNotificationPreference.on;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      settings = TileNotificationSettings(prefs, widget.feature);
      value = settings!.read();
    });
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '${widget.title} · 通知设置',
              style: Theme.of(context).textTheme.titleLarge,
            ),
          ),
          for (final option in TileNotificationPreference.values)
            ListTile(
              leading: Icon(option.icon),
              title: Text(option.title),
              subtitle: Text(option.description),
              trailing: value == option
                  ? const Icon(Icons.check_rounded)
                  : null,
              enabled: settings != null,
              onTap: () async {
                await settings!.set(option);
                if (mounted) setState(() => value = option);
              },
            ),
          const Padding(
            padding: EdgeInsets.all(12),
            child: Text('当前保存此磁贴的通知偏好，具体提醒功能尚未开放。'),
          ),
        ],
      ),
    ),
  );
}
