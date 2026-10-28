import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../demo_data.dart';

class AdvertisementDeck extends StatefulWidget {
  const AdvertisementDeck({super.key});
  @override
  State<AdvertisementDeck> createState() => _AdvertisementDeckState();
}

class _AdvertisementDeckState extends State<AdvertisementDeck> {
  int selected = 0;
  double drag = 0;
  void advance(int step) => setState(() {
    selected = (selected + step) % DemoData.largeAdAssets.length;
    drag = 0;
  });
  @override
  Widget build(BuildContext context) => Semantics(
    label: '广告图片叠放',
    value: '第 ${selected + 1} 张，共 ${DemoData.largeAdAssets.length} 张',
    increasedValue:
        '第 ${(selected + 1) % DemoData.largeAdAssets.length + 1} 张，共 ${DemoData.largeAdAssets.length} 张',
    decreasedValue:
        '第 ${(selected - 1 + DemoData.largeAdAssets.length) % DemoData.largeAdAssets.length + 1} 张，共 ${DemoData.largeAdAssets.length} 张',
    onIncrease: () => advance(1),
    onDecrease: () => advance(-1),
    child: LayoutBuilder(
      builder: (context, size) => GestureDetector(
        onHorizontalDragUpdate: (details) =>
            setState(() => drag += details.delta.dx),
        onHorizontalDragEnd: (details) {
          if (drag.abs() > size.maxWidth * .18 ||
              details.velocity.pixelsPerSecond.dx.abs() > 350) {
            advance(
              (drag == 0 ? details.velocity.pixelsPerSecond.dx : drag) < 0
                  ? 1
                  : -1,
            );
          } else {
            setState(() => drag = 0);
          }
        },
        onHorizontalDragCancel: () => setState(() => drag = 0),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => AdvertisementPage(initialIndex: selected),
          ),
        ),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var depth = 2; depth >= 0; depth--)
              Positioned.fill(
                child: AnimatedContainer(
                  duration: Duration(
                    milliseconds: MediaQuery.disableAnimationsOf(context)
                        ? 0
                        : 170,
                  ),
                  transformAlignment: Alignment.center,
                  transform: Matrix4.identity()
                    ..translateByDouble(
                      depth == 0
                          ? drag.clamp(-size.maxWidth, size.maxWidth)
                          : depth * 3.0,
                      depth * 2.0,
                      0,
                      1,
                    )
                    ..rotateZ(
                      depth == 0 ? drag / size.maxWidth * .07 : depth * .045,
                    )
                    ..scaleByDouble(1 - depth * .04, 1 - depth * .04, 1, 1),
                  child: Material(
                    elevation: 2 + depth.toDouble(),
                    borderRadius: BorderRadius.circular(22),
                    clipBehavior: Clip.antiAlias,
                    child: Image.asset(
                      DemoData.largeAdAssets[(selected + depth) %
                          DemoData.largeAdAssets.length],
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class AdvertisementPage extends StatefulWidget {
  const AdvertisementPage({super.key, this.initialIndex = 0});
  final int initialIndex;
  @override
  State<AdvertisementPage> createState() => _AdvertisementPageState();
}

class _AdvertisementPageState extends State<AdvertisementPage> {
  late int selected = widget.initialIndex.clamp(
    0,
    DemoData.largeAdAssets.length - 1,
  );
  bool grid = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: Colors.black,
      foregroundColor: Colors.white,
      title: Text('${selected + 1} / ${DemoData.largeAdAssets.length}'),
      actions: [
        IconButton(
          tooltip: grid ? '查看单张' : '查看全部图片',
          onPressed: () => setState(() => grid = !grid),
          icon: Icon(grid ? Icons.photo_outlined : Icons.grid_view_rounded),
        ),
      ],
    ),
    body: SafeArea(
      child: grid
          ? GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              itemCount: DemoData.largeAdAssets.length,
              itemBuilder: (context, i) => InkWell(
                onTap: () => setState(() {
                  selected = i;
                  grid = false;
                }),
                child: Image.asset(
                  DemoData.largeAdAssets[i],
                  fit: BoxFit.cover,
                ),
              ),
            )
          : _AdvertisementPager(
              initialIndex: selected,
              onChanged: (i) => setState(() => selected = i),
            ),
    ),
    bottomNavigationBar: const SafeArea(
      child: Padding(
        padding: EdgeInsets.all(14),
        child: Text(
          '本地演示广告素材',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70),
        ),
      ),
    ),
  );
}

class _AdvertisementPager extends StatefulWidget {
  const _AdvertisementPager({
    required this.initialIndex,
    required this.onChanged,
  });
  final int initialIndex;
  final ValueChanged<int> onChanged;
  @override
  State<_AdvertisementPager> createState() => _AdvertisementPagerState();
}

class _AdvertisementPagerState extends State<_AdvertisementPager> {
  late final controller = PageController(initialPage: widget.initialIndex);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => PageView.builder(
    controller: controller,
    onPageChanged: widget.onChanged,
    itemCount: DemoData.largeAdAssets.length,
    itemBuilder: (context, i) => Center(
      child: InteractiveViewer(
        maxScale: math.max(2, 4),
        child: Image.asset(DemoData.largeAdAssets[i], fit: BoxFit.contain),
      ),
    ),
  );
}
