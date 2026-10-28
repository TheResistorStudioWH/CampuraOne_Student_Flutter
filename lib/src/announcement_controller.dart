import 'dart:async';

import 'package:flutter/widgets.dart';

import 'announcement_feed.dart';
import 'demo_data.dart';

/// A shared live snapshot for the banner, pinned controls and open notice pages.
/// No credentials means demo mode, with no network or AI requests.
class AnnouncementController extends ChangeNotifier
    with WidgetsBindingObserver {
  AnnouncementController({
    this.feed,
    this.token,
    List<CampusAnnouncement>? demoNotices,
    DateTime Function()? clock,
    this.automatic = true,
  }) : _clock = clock ?? DateTime.now,
       _all = token == null
           ? List.of(demoNotices ?? DemoData.announcements)
           : [];
  final AnnouncementFeed? feed;
  final String? token;
  final DateTime Function() _clock;
  final bool automatic;
  List<CampusAnnouncement> _all;
  List<CampusAnnouncement> _visible = [];
  String? summary;
  bool loadFailed = false, loading = false;
  bool _active = false, _disposed = false, _summaryBusy = false;
  bool _observing = false;
  int _generation = 0, _revision = 0, _attempts = 0;
  DateTime? _nextPoll, _nextSummary, _lastSummary;
  Timer? _timer;
  String _fingerprint = '';
  bool get isDemo => token == null;
  List<CampusAnnouncement> get notices => List.unmodifiable(_visible);
  List<CampusAnnouncement> get important =>
      _visible.where((n) => n.type == 2).toList()..sort((a, b) {
        final dates = (b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0))
            .compareTo(a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0));
        return dates != 0 ? dates : b.id.compareTo(a.id);
      });
  List<CampusAnnouncement> get short =>
      _visible.where((n) => n.type != 2).toList()..sort((a, b) {
        final end = (a.endTime ?? DateTime(9999)).compareTo(
          b.endTime ?? DateTime(9999),
        );
        return end != 0 ? end : b.id.compareTo(a.id);
      });
  String get summaryLabel => summary ?? (isDemo ? '摘要不可用 · 演示通知' : '摘要不可用');

  void start() {
    if (_disposed || _active) return;
    _active = true;
    if (automatic && !_observing) {
      WidgetsBinding.instance.addObserver(this);
      _observing = true;
    }
    _nextPoll = _clock();
    if (summary == null) {
      _attempts = 0;
      _nextSummary = _lastSummary?.add(const Duration(seconds: 30)) ?? _clock();
    }
    _updateVisible();
    if (automatic &&
        (!isDemo ||
            _all.any((n) => n.startTime != null || n.endTime != null))) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) => tick());
    }
    unawaited(tick());
  }

  void pause() {
    _active = false;
    _generation++;
    _timer?.cancel();
    loading = false;
    _summaryBusy = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      start();
    } else {
      pause();
    }
  }

  void _updateVisible() {
    final current = _all.where((n) => n.isActive(_clock())).toList();
    final fingerprints = current.map((n) => n.fingerprint).toList()..sort();
    final fingerprint = fingerprints.join('\u0000');
    if (_fingerprint == fingerprint) return;
    _visible = current;
    _fingerprint = fingerprint;
    _revision++;
    summary = null;
    _attempts = 0;
    _nextSummary = _clock();
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    _nextPoll = _clock();
    await tick();
  }

  Future<void> tick() async {
    if (!_active || _disposed) return;
    _updateVisible();
    if (isDemo || feed == null || token!.trim().isEmpty) return;
    final generation = _generation;
    if (!loading && (_nextPoll == null || !_clock().isBefore(_nextPoll!))) {
      loading = true;
      notifyListeners();
      try {
        final notices = await feed!.loadNotices(token!);
        if (!_accepts(generation)) return;
        _all = notices;
        loadFailed = false;
        _nextPoll = _clock().add(const Duration(seconds: 60));
        _updateVisible();
      } catch (_) {
        if (!_accepts(generation)) return;
        loadFailed = true;
        _nextPoll = _clock().add(const Duration(seconds: 30));
      } finally {
        if (_accepts(generation)) {
          loading = false;
          notifyListeners();
        }
      }
    }
    if (!_accepts(generation) ||
        loading ||
        loadFailed ||
        _visible.isEmpty ||
        summary != null ||
        _summaryBusy ||
        _attempts >= 3 ||
        (_nextSummary != null && _clock().isBefore(_nextSummary!))) {
      return;
    }
    final revision = _revision;
    _summaryBusy = true;
    _lastSummary = _clock();
    _attempts++;
    try {
      final result = await feed!.loadSummary(token!);
      if (!_accepts(generation)) return;
      _updateVisible();
      if (_revision != revision) return;
      if (result == null || !result.validFor(_visible)) {
        throw const FormatException('Invalid summary source');
      }
      summary = result.text;
    } catch (_) {
      if (_accepts(generation) && revision == _revision) {
        _nextSummary = _clock().add(Duration(seconds: _attempts == 1 ? 5 : 30));
      }
    } finally {
      if (_accepts(generation)) {
        _summaryBusy = false;
        notifyListeners();
      }
    }
  }

  bool _accepts(int generation) =>
      !_disposed && _active && generation == _generation;
  @override
  void dispose() {
    pause();
    if (_observing) WidgetsBinding.instance.removeObserver(this);
    _disposed = true;
    super.dispose();
  }
}
