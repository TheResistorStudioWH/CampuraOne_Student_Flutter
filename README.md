# 域校屿学生端 · Android 与 Wear OS

手机应用使用 Flutter（`lib/main.dart`），手表应用是同一 Android 工程下的原生 `android/wear/` 模块，使用 Compose for Wear OS Material 3。两个 APK 的包名均为 `com.campura.one.campura_one_student`，但手表有独立版本号和手表设备限定。当前手表可独立联网使用。

## 构建

手表构建从 `android/` 执行：

```sh
JAVA_HOME=/path/to/jdk17 ./gradlew :wear:testDebugUnitTest :wear:assembleDebug
```

本机账户配置放在被 Git 忽略的 `android/wear.local.properties`：

```properties
wear.userName=（本机账户名）
wear.password=（本机密码）
```

也可通过 `CAMPURA_WEAR_USER` 和 `CAMPURA_WEAR_PASSWORD` 环境变量构建。缺少配置时，手表显示可重试的认证错误。构建值会进入 APK，不能用于正式发布；不要把该文件、构建产物或凭据写入仓库。手表 debug APK 位于 `build/wear/outputs/apk/debug/wear-debug.apk`。

手机端从此目录执行 `flutter test` 和 `flutter build apk --debug`；高德 Key 仍需通过 `--dart-define=AMAP_ANDROID_KEY=...` 注入，不能提交。手机 debug APK 位于 `build/app/outputs/flutter-apk/app-debug.apk`。手机与手表 debug 包使用同一包名和 debug 签名，分别安装到不同类型设备。正式签名与发布版本号需要在发布前统一配置。

## 手表功能

- 首页提供课表与校历入口；课表有列表、日、周总览、月视图，校历有列表、日、月视图。
- 日期切换、日期选择、回到今天、事项详情与手动刷新；右滑返回，表冠滚动列表。
- 登录后根据学生资料中的学校、校区、院系和班级范围获取现有 PHP 接口返回的 ICS。401 最多重新认证一次；会话只留在内存。
- 成功数据保存在手表本地；启动先读缓存再刷新，回到前台超过五分钟刷新。请求失败保留上次成功内容与更新时间。

未来登录：Android 手机完成登录后，用 Wear OS Data Layer 向手表同步会话和退出状态；取不到有效手机会话时再加入扫码授权。当前未实现这两步，也没有新的服务端接口。

## 本地验证

`./gradlew :wear:testDebugUnitTest :wear:assembleDebug` 已通过 10 项手表数据、缓存和认证测试。`flutter test` 通过 17 项手机测试，`dart analyze lib test` 无提示。Wear OS 6 圆屏 384×384 模拟器已验证首页、课表和校历各显示模式、事项详情、表冠滚动、右滑返回、日期网格及 HTTPS 获取内容。真机仍需设备验收。
