import 'package:flutter/material.dart';

import 'tile_settings.dart';

class DetailScaffold extends StatelessWidget {
  const DetailScaffold({
    super.key,
    required this.title,
    required this.child,
    this.actions,
    this.feature,
  });
  final String title;
  final Widget child;
  final List<Widget>? actions;
  final String? feature;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(title),
      actions: [
        ...?actions,
        if (feature != null)
          IconButton(
            tooltip: '磁贴设置',
            onPressed: () => showTileSettings(context, feature!, title),
            icon: const Icon(Icons.tune_rounded),
          ),
      ],
    ),
    body: SafeArea(child: child),
  );
}
