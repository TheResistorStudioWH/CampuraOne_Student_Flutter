import 'package:flutter/material.dart';

import 'demo_data.dart';
import 'schedule/course_page.dart';
import 'calendar/calendar_widgets.dart';
import 'widgets/detail_scaffold.dart';
export 'schedule/course_page.dart';
export 'calendar/calendar_widgets.dart' show CalendarPage;
export 'widgets/detail_scaffold.dart';
export 'widgets/announcements.dart'
    show AnnouncementsPage, MarkdownAnnouncementsPage;
export 'widgets/advertisement_deck.dart' show AdvertisementPage;

class PromotionsPage extends StatefulWidget {
  const PromotionsPage({super.key, this.initialHot = false});
  final bool initialHot;
  @override
  State<PromotionsPage> createState() => _PromotionsPageState();
}

class _PromotionsPageState extends State<PromotionsPage> {
  late bool hot = widget.initialHot;
  late List<CampusPromotion> random = [...DemoData.promotions]..shuffle();

  @override
  Widget build(BuildContext context) {
    final events = (hot ? [...DemoData.promotions] : random)
        .where((s) => s.isActive)
        .toList();
    if (hot) {
      events.sort(
        (a, b) => (a.endTime ?? DateTime(9999)).compareTo(
          b.endTime ?? DateTime(9999),
        ),
      );
    }
    return DetailScaffold(
      title: '最近促销',
      feature: 'salesTimeline',
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
                label: Text('热榜'),
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
              child: Text('演示榜单按结束时间排列 · 暂无真实热度数据'),
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
        subtitle: Text('${product.name} · ${sale.remainingLabel}'),
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
