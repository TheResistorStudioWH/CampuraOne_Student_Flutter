# AMap Flutter 本地兼容补丁

`amap_flutter_map` 和 `amap_flutter_base` 的源码来自高德官方 pub.dev 3.0.0 版本，许可证保留在各包的 `LICENSE`。两包以本地 path 依赖纳入工程，避免改动全局 pub 缓存。

当前 Flutter 3.47 / Dart 3 / Android Gradle Plugin 9 构建需要以下修复：

- 地图插件改用当前 Android library DSL、`namespace` 和 Maven Central 中的 `com.amap.api:3dmap:8.1.0`，移除失效的 `jcenter()`。
- 基础库与地图插件将已移除的 Dart `hashValues` 改为 `Object.hash`。
- 地图插件删除 Flutter Android v1 的 `Registrar` 注册代码，并使用当前 `FlutterInjector` 查询资源键；v2 注册逻辑保留。
- pubspec 的 SDK 约束和插件平台声明与当前 Android 工程匹配。

APK 编译已通过；尚无高德 Key 与 Android 真机，运行时地图行为需要在取得 Key 后验证。升级高德插件时应重新评估这些补丁，避免直接覆盖本地源码。
