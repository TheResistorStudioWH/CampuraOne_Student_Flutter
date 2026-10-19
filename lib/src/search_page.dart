import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'demo_data.dart';
import 'detail_pages.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});
  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  static const _historyKey = 'campura.search.history';
  final controller = TextEditingController();
  SearchMode mode = SearchMode.smart;
  List<String> history = [];
  String query = '';
  bool submitted = false;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_historyKey);
    if (!mounted || raw == null) return;
    try {
      setState(() => history = List<String>.from(jsonDecode(raw) as List));
    } on FormatException {
      setState(() => history = []);
    }
  }

  Future<void> _submit(String value) async {
    final cleaned = value.trim();
    if (cleaned.isEmpty) return;
    final updated = [
      cleaned,
      ...history.where((item) => item != cleaned),
    ].take(12).toList();
    setState(() {
      query = cleaned;
      submitted = true;
      history = updated;
      controller.text = cleaned;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_historyKey, jsonEncode(updated));
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hits = searchDemo(query, mode);
    return Scaffold(
      appBar: AppBar(title: const Text('校园搜索')),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SearchBar(
                controller: controller,
                autoFocus: true,
                hintText: '搜索促销、商品和商户',
                leading: const Icon(Icons.search_rounded),
                trailing: [
                  if (query.isNotEmpty)
                    IconButton(
                      tooltip: '清除',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        controller.clear();
                        setState(() {
                          query = '';
                          submitted = false;
                        });
                      },
                    ),
                ],
                onChanged: (value) => setState(() {
                  query = value;
                  submitted = false;
                }),
                onSubmitted: _submit,
              ),
            ),
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: SearchMode.values
                    .map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(item.title),
                          selected: mode == item,
                          onSelected: (_) => setState(() => mode = item),
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
            Expanded(
              child: query.trim().isEmpty
                  ? _historyList()
                  : hits.isEmpty
                  ? const Center(child: Text('没有找到匹配的演示内容'))
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        if (mode == SearchMode.smart && hits.isNotEmpty) ...[
                          Text(
                            '猜你想找',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ActionChip(
                            avatar: Icon(hits.first.icon, size: 18),
                            label: Text(hits.first.title),
                            onPressed: () => _openHit(hits.first),
                          ),
                          const SizedBox(height: 14),
                        ],
                        Text(
                          submitted ? '搜索结果' : '实时建议',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        for (final hit in hits)
                          Card(
                            child: ListTile(
                              leading: CircleAvatar(child: Icon(hit.icon)),
                              title: Text(hit.title),
                              subtitle: Text(hit.subtitle),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () {
                                _submit(query);
                                _openHit(hit);
                              },
                            ),
                          ),
                        const SizedBox(height: 14),
                        Text(
                          '本地演示搜索 · 接入登录后使用 Server/search.php',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _historyList() {
    if (history.isEmpty) {
      return const Center(child: Text('输入关键词，查找校园商户与商品'));
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Row(
          children: [
            Text('最近搜索', style: Theme.of(context).textTheme.titleMedium),
            const Spacer(),
            TextButton(
              onPressed: () async {
                final prefs = await SharedPreferences.getInstance();
                await prefs.remove(_historyKey);
                if (mounted) setState(() => history = []);
              },
              child: const Text('清除'),
            ),
          ],
        ),
        for (final item in history)
          ListTile(
            leading: const Icon(Icons.history_rounded),
            title: Text(item),
            onTap: () => _submit(item),
          ),
      ],
    );
  }

  void _openHit(SearchHit hit) {
    Widget page;
    switch (hit.kind) {
      case 'shop':
        page = ShopPage(
          shop: DemoData.shops.firstWhere((s) => s.id == hit.targetId),
        );
      case 'product':
        page = ProductPage(
          product: DemoData.products.firstWhere((p) => p.id == hit.targetId),
        );
      default:
        final sale = DemoData.promotions.firstWhere(
          (s) => s.id == hit.targetId,
        );
        page = ProductPage(
          product: DemoData.products.firstWhere((p) => p.id == sale.productId),
        );
    }
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}
