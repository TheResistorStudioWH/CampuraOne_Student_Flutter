import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import 'demo_data.dart';

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title), actions: actions),
    body: SafeArea(child: child),
  );
}

class CoursePage extends StatefulWidget {
  const CoursePage({super.key});
  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> {
  static const _calendarChannel = MethodChannel('campura.one/calendar');
  DateTime selected = DateUtils.dateOnly(DateTime.now());
  DateTime railCenter = DateUtils.dateOnly(DateTime.now());
  final railController = ScrollController(initialScrollOffset: 320);

  @override
  void dispose() {
    railController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: selected,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (date != null) {
      setState(() {
        selected = date;
        railCenter = date;
      });
      if (railController.hasClients) railController.jumpTo(320);
    }
  }

  Future<void> _addCalendar(CampusCourse course) async {
    try {
      await _calendarChannel.invokeMethod<void>('insertEvent', {
        'title': course.title,
        'location': course.location,
        'description': course.teacher,
        'startMillis': course.startOn(selected).millisecondsSinceEpoch,
        'endMillis': course.endOn(selected).millisecondsSinceEpoch,
      });
    } on PlatformException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('没有找到可添加日程的日历应用')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final courses = DemoData.coursesOn(selected);
    final colors = Theme.of(context).colorScheme;
    final railDays = List.generate(
      15,
      (i) => railCenter.add(Duration(days: i - 7)),
    );
    return DetailScaffold(
      title: '课程表',
      actions: [
        IconButton(
          tooltip: '选择日期',
          onPressed: _pickDate,
          icon: const Icon(Icons.date_range_rounded),
        ),
      ],
      child: Row(
        children: [
          SizedBox(
            width: 68,
            child: ListView.builder(
              controller: railController,
              padding: const EdgeInsets.only(top: 96, bottom: 24),
              itemCount: railDays.length,
              itemBuilder: (context, index) {
                final date = railDays[index];
                final isSelected = DateUtils.isSameDay(date, selected);
                return Padding(
                  padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
                  child: Material(
                    color: isSelected
                        ? colors.primaryContainer
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => setState(() => selected = date),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Column(
                          children: [
                            Text(
                              '周${_weekday(date.weekday)}',
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                            Text(
                              '${date.day}',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(8, 16, 16, 28),
              children: [
                Text(
                  '${selected.year}年${selected.month}月${selected.day}日 · 周${_weekday(selected.weekday)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 5),
                Text(
                  '当天共 ${courses.length} 节课 · 演示课表',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 20),
                if (courses.isEmpty)
                  const _EmptyState(
                    icon: Icons.event_available_rounded,
                    title: '当天暂无课程',
                    subtitle: '可在左侧切换日期，或用右上角选择日期。',
                  ),
                for (final course in courses)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            course.timeLabel,
                            style: Theme.of(context).textTheme.labelLarge
                                ?.copyWith(color: colors.primary),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            course.title,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          Text('${course.location} · ${course.teacher}'),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.event_rounded),
                            label: const Text('添加到系统日历'),
                            onPressed: () => _addCalendar(course),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _weekday(int day) => '一二三四五六日'[day - 1];

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime selected = DateUtils.dateOnly(DateTime.now());

  @override
  Widget build(BuildContext context) {
    final dayEvents = DemoData.calendarEvents
        .where((e) => e.includes(selected))
        .toList();
    return DetailScaffold(
      title: '校历',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          Card(
            child: CalendarDatePicker(
              key: ValueKey('${selected.year}-${selected.month}'),
              initialDate: selected,
              firstDate: DateTime(2020),
              lastDate: DateTime(2035),
              currentDate: DateTime.now(),
              onDateChanged: (value) => setState(() => selected = value),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${selected.month}月${selected.day}日',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (dayEvents.isEmpty)
            const _EmptyState(
              icon: Icons.calendar_today_rounded,
              title: '当天无校历事项',
              subtitle: '选择其他日期查看活动和教学安排。',
            ),
          for (final event in dayEvents)
            Card(
              child: ListTile(
                leading: const Icon(Icons.event_note_rounded),
                title: Text(event.title),
                subtitle: Text(event.category),
              ),
            ),
          const SizedBox(height: 14),
          Text('近期事项', style: Theme.of(context).textTheme.titleMedium),
          for (final event in DemoData.calendarEvents)
            ListTile(
              leading: const Icon(Icons.circle, size: 11),
              title: Text(event.title),
              subtitle: Text(
                '${event.start.month}月${event.start.day}日 · ${event.category}',
              ),
              onTap: () => setState(() {
                selected = event.start;
              }),
            ),
        ],
      ),
    );
  }
}

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key});
  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  bool hot = false;
  late List<CampusPromotion> random = [...DemoData.promotions]..shuffle();

  @override
  Widget build(BuildContext context) {
    final events = hot ? DemoData.promotions : random;
    return DetailScaffold(
      title: '最近促销',
      actions: [
        IconButton(
          tooltip: '刷新推荐',
          onPressed: () =>
              setState(() => random = [...DemoData.promotions]..shuffle()),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(
                value: false,
                label: Text('随机推荐'),
                icon: Icon(Icons.shuffle_rounded),
              ),
              ButtonSegment(
                value: true,
                label: Text('热门'),
                icon: Icon(Icons.local_fire_department_rounded),
              ),
            ],
            selected: {hot},
            onSelectionChanged: (value) => setState(() => hot = value.first),
          ),
          const SizedBox(height: 14),
          if (hot)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: Text('演示排序 · 热度数据尚未接入'),
            ),
          for (final sale in events) _promotionCard(context, sale),
        ],
      ),
    );
  }

  Widget _promotionCard(BuildContext context, CampusPromotion sale) {
    final product = DemoData.products.firstWhere((p) => p.id == sale.productId);
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(child: Icon(product.icon)),
        title: Text(sale.rule),
        subtitle: Text('${product.name} · ${sale.subtitle}'),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => ProductPage(product: product),
          ),
        ),
      ),
    );
  }
}

class AdvertisementPage extends StatelessWidget {
  const AdvertisementPage({super.key});
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '推荐广告',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('本地演示广告素材'),
        const SizedBox(height: 12),
        for (final path in DemoData.largeAdAssets)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: AspectRatio(
                aspectRatio: 3,
                child: Image.asset(path, fit: BoxFit.cover),
              ),
            ),
          ),
      ],
    ),
  );
}

class ToolboxPage extends StatelessWidget {
  const ToolboxPage({super.key});
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '工具箱',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_month_rounded),
            title: const Text('课程表'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const CoursePage())),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.event_note_rounded),
            title: const Text('校历'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CalendarPage()),
            ),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_rounded),
            title: const Text('校园商户'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute<void>(builder: (_) => const ShopsPage())),
          ),
        ),
      ],
    ),
  );
}

class AnnouncementsPage extends StatefulWidget {
  const AnnouncementsPage({super.key, this.announcements});
  final List<CampusAnnouncement>? announcements;
  @override
  State<AnnouncementsPage> createState() => _AnnouncementsPageState();
}

class _AnnouncementsPageState extends State<AnnouncementsPage> {
  int? filter;

  @override
  Widget build(BuildContext context) {
    final items =
        (widget.announcements ?? DemoData.announcements)
            .where((a) => a.type != 2 && (filter == null || a.type == filter))
            .toList()
          ..sort((a, b) => b.type.compareTo(a.type));
    return DetailScaffold(
      title: '短通知',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('全部'),
                selected: filter == null,
                onSelected: (_) => setState(() => filter = null),
              ),
              for (final type in [1, 0])
                ChoiceChip(
                  label: Text(switch (type) {
                    1 => '紧急',
                    _ => '日常',
                  }),
                  selected: filter == type,
                  onSelected: (_) => setState(() => filter = type),
                ),
            ],
          ),
          const SizedBox(height: 12),
          for (final item in items)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                contentPadding: const EdgeInsets.all(14),
                leading: Icon(
                  item.type == 1
                      ? Icons.warning_amber_rounded
                      : Icons.notifications_outlined,
                ),
                title: Text(item.category),
                subtitle: Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => DetailScaffold(
                      title: '${item.category}通知',
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: SelectableText(
                          item.content,
                          style: Theme.of(context).textTheme.bodyLarge,
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
}

class MarkdownAnnouncementsPage extends StatelessWidget {
  const MarkdownAnnouncementsPage({super.key, required this.announcements});
  final List<CampusAnnouncement> announcements;

  @override
  Widget build(BuildContext context) {
    final important = announcements.where((item) => item.type == 2).toList();
    return DetailScaffold(
      title: '重要通知',
      child: important.isEmpty
          ? const Center(child: Text('暂无重要通知'))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                for (final item in important)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.priority_high_rounded),
                      title: Text('重要通知 ${item.id}'),
                      subtitle: Text(
                        item.content.replaceAll(RegExp(r'[#*`]'), '').trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) => DetailScaffold(
                            title: '重要通知',
                            child: Markdown(
                              data: item.content,
                              padding: const EdgeInsets.all(20),
                              selectable: true,
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
}

class ShopsPage extends StatelessWidget {
  const ShopsPage({super.key});
  @override
  Widget build(BuildContext context) => DetailScaffold(
    title: '校园商户',
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final shop in DemoData.shops)
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Icon(shop.icon)),
              title: Text(shop.name),
              subtitle: Text('${shop.slogan}\n${shop.address}'),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => ShopPage(shop: shop)),
              ),
            ),
          ),
      ],
    ),
  );
}

class ShopPage extends StatelessWidget {
  const ShopPage({super.key, required this.shop});
  final CampusShop shop;
  @override
  Widget build(BuildContext context) {
    final products = DemoData.products
        .where((p) => p.shopId == shop.id)
        .toList();
    return DetailScaffold(
      title: shop.name,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(shop.icon, size: 42),
                  const SizedBox(height: 12),
                  Text(
                    shop.slogan,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(shop.address),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text('商品', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          for (final product in products)
            Card(
              child: ListTile(
                leading: CircleAvatar(child: Icon(product.icon)),
                title: Text(product.name),
                subtitle: Text(product.introduction),
                trailing: Text('¥${product.price.toStringAsFixed(0)}'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => ProductPage(product: product),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProductPage extends StatelessWidget {
  const ProductPage({super.key, required this.product});
  final CampusProduct product;
  @override
  Widget build(BuildContext context) {
    final shop = DemoData.shops.firstWhere((s) => s.id == product.shopId);
    final sales = DemoData.promotions.where((s) => s.productId == product.id);
    return DetailScaffold(
      title: product.name,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 210,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(product.icon, size: 100),
          ),
          const SizedBox(height: 20),
          Text(product.name, style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 6),
          Text(
            '¥${product.price.toStringAsFixed(2)}',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(color: Theme.of(context).colorScheme.primary),
          ),
          const SizedBox(height: 16),
          Text(product.introduction),
          const SizedBox(height: 14),
          for (final sale in sales)
            Chip(
              avatar: const Icon(Icons.sell_rounded, size: 18),
              label: Text(sale.rule),
            ),
          const SizedBox(height: 16),
          ListTile(
            leading: Icon(shop.icon),
            title: Text(shop.name),
            subtitle: Text(shop.address),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => ShopPage(shop: shop)),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 12),
    child: Column(
      children: [
        Icon(icon, size: 48, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 5),
        Text(subtitle, textAlign: TextAlign.center),
      ],
    ),
  );
}
