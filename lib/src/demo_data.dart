import 'package:flutter/material.dart';

/// Demo content is deliberately separate from the PHP API contract.
/// No student identity or private campus data is inferred from this fixture.
class DemoData {
  DemoData._();
  static const studentName = '小屿';
  static const schoolName = '域校屿示例校园';
  static const weatherPlace = '武汉 · 江夏';
  static const weatherTemperature = 24;

  static final announcements = <CampusAnnouncement>[
    CampusAnnouncement(1, '## 演示重要通知\n\n本周校园活动安排已更新，请留意校历中的活动时间。', 2),
    CampusAnnouncement(2, '欢迎使用域校屿 Android 演示版。这里显示学校通知。', 0),
    CampusAnnouncement(3, '如遇紧急通知，将在这里优先展示。', 1),
  ];

  static final courses = <CampusCourse>[
    const CampusCourse('大学英语', 1, 8, 0, 9, 35, '教学楼 A203', '陈老师'),
    const CampusCourse('高等数学', 1, 10, 0, 11, 35, '教学楼 B101', '李老师'),
    const CampusCourse('程序设计基础', 2, 8, 0, 9, 35, '实训楼 402', '王老师'),
    const CampusCourse('体育', 2, 15, 0, 16, 35, '体育场', '赵老师'),
    const CampusCourse('线性代数', 3, 10, 0, 11, 35, '教学楼 A305', '刘老师'),
    const CampusCourse('思想道德与法治', 4, 8, 0, 9, 35, '教学楼 C202', '周老师'),
    const CampusCourse('计算机导论', 4, 14, 0, 15, 35, '实训楼 301', '孙老师'),
    const CampusCourse('班会', 5, 16, 0, 17, 0, '教学楼 A203', '辅导员'),
  ];

  static final calendarEvents = <CampusCalendarEvent>[
    CampusCalendarEvent(
      '开学周',
      DateTime(2026, 9, 1),
      DateTime(2026, 9, 7),
      '学期安排',
    ),
    CampusCalendarEvent(
      '校内社团展示',
      DateTime(2026, 10, 16),
      DateTime(2026, 10, 16),
      '校园活动',
    ),
    CampusCalendarEvent(
      '期中教学反馈',
      DateTime(2026, 11, 9),
      DateTime(2026, 11, 13),
      '教学安排',
    ),
    CampusCalendarEvent(
      '冬季运动会',
      DateTime(2026, 12, 5),
      DateTime(2026, 12, 5),
      '校园活动',
    ),
  ];

  static const shops = <CampusShop>[
    CampusShop(1, '湖畔咖啡', '生活服务区 · 1 楼', '咖啡与轻食', Icons.local_cafe_rounded),
    CampusShop(2, '校园书屋', '图书馆 · 1 楼', '书籍与文具', Icons.menu_book_rounded),
    CampusShop(3, '一号食堂', '中心广场东侧', '餐饮', Icons.restaurant_rounded),
  ];

  static const products = <CampusProduct>[
    CampusProduct(101, 1, '拿铁咖啡', 16, '现磨咖啡，冷热可选', Icons.coffee_rounded),
    CampusProduct(102, 1, '鸡肉三明治', 18, '轻食午餐', Icons.lunch_dining_rounded),
    CampusProduct(103, 2, '课堂笔记本', 8, 'A5 方格笔记本', Icons.edit_note_rounded),
    CampusProduct(104, 3, '午餐套餐', 22, '主食与配菜组合', Icons.ramen_dining_rounded),
  ];

  static const promotions = <CampusPromotion>[
    CampusPromotion(201, 101, '咖啡第二杯半价', '今日精选'),
    CampusPromotion(202, 104, '午餐套餐优惠', '食堂活动'),
    CampusPromotion(203, 103, '开学文具组合价', '校园书屋'),
  ];

  static const largeAdAssets = [
    'assets/demo/ad_banner1.png',
    'assets/demo/ad_banner2.png',
    'assets/demo/ad_banner3.png',
    'assets/demo/ad_banner4.png',
  ];

  static List<CampusCourse> coursesOn(DateTime date) =>
      courses.where((course) => course.weekday == date.weekday).toList()
        ..sort((a, b) => a.startHour.compareTo(b.startHour));
}

class CampusAnnouncement {
  const CampusAnnouncement(this.id, this.content, this.type);
  final int id;
  final String content;

  /// 0 daily, 1 emergency, 2 important Markdown, matching the Server.
  final int type;
  String get category => switch (type) {
    1 => '紧急',
    2 => '重要',
    _ => '日常',
  };
}

class CampusCourse {
  const CampusCourse(
    this.title,
    this.weekday,
    this.startHour,
    this.startMinute,
    this.endHour,
    this.endMinute,
    this.location,
    this.teacher,
  );
  final String title;
  final int weekday;
  final int startHour;
  final int startMinute;
  final int endHour;
  final int endMinute;
  final String location;
  final String teacher;
  DateTime startOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, startHour, startMinute);
  DateTime endOn(DateTime date) =>
      DateTime(date.year, date.month, date.day, endHour, endMinute);
  String get timeLabel =>
      '${_clock(startHour, startMinute)}–${_clock(endHour, endMinute)}';
  static String _clock(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}

class CampusCalendarEvent {
  const CampusCalendarEvent(this.title, this.start, this.end, this.category);
  final String title;
  final DateTime start;
  final DateTime end;
  final String category;
  bool includes(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    return !d.isBefore(start) && !d.isAfter(end);
  }
}

class CampusShop {
  const CampusShop(this.id, this.name, this.address, this.slogan, this.icon);
  final int id;
  final String name;
  final String address;
  final String slogan;
  final IconData icon;
}

class CampusProduct {
  const CampusProduct(
    this.id,
    this.shopId,
    this.name,
    this.price,
    this.introduction,
    this.icon,
  );
  final int id;
  final int shopId;
  final String name;
  final double price;
  final String introduction;
  final IconData icon;
}

class CampusPromotion {
  const CampusPromotion(this.id, this.productId, this.rule, this.subtitle);
  final int id;
  final int productId;
  final String rule;
  final String subtitle;
}

enum SearchMode {
  smart('智能全局', 'smart'),
  all('全局', 'all'),
  product('按商品', 'product'),
  shop('按商户', 'shop');

  const SearchMode(this.title, this.apiValue);
  final String title;
  final String apiValue;
}

class SearchHit {
  const SearchHit(
    this.kind,
    this.targetId,
    this.title,
    this.subtitle,
    this.icon,
  );
  final String kind;
  final int targetId;
  final String title;
  final String subtitle;
  final IconData icon;
}

List<SearchHit> searchDemo(String query, SearchMode mode) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return [];
  final hits = <SearchHit>[];
  if (mode == SearchMode.all || mode == SearchMode.smart) {
    for (final sale in DemoData.promotions) {
      final product = DemoData.products.firstWhere(
        (p) => p.id == sale.productId,
      );
      if ('${sale.rule} ${sale.subtitle} ${product.name}'
          .toLowerCase()
          .contains(q)) {
        hits.add(
          SearchHit(
            'promotion',
            sale.id,
            sale.rule,
            product.name,
            Icons.sell_rounded,
          ),
        );
      }
    }
  }
  if (mode != SearchMode.shop) {
    for (final product in DemoData.products) {
      if ('${product.name} ${product.introduction}'.toLowerCase().contains(q)) {
        hits.add(
          SearchHit(
            'product',
            product.id,
            product.name,
            '¥${product.price.toStringAsFixed(0)} · ${product.introduction}',
            product.icon,
          ),
        );
      }
    }
  }
  if (mode != SearchMode.product) {
    for (final shop in DemoData.shops) {
      if ('${shop.name} ${shop.slogan} ${shop.address}'.toLowerCase().contains(
        q,
      )) {
        hits.add(
          SearchHit('shop', shop.id, shop.name, shop.address, shop.icon),
        );
      }
    }
  }
  return hits;
}
