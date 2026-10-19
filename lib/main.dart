import 'package:animations/animations.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'src/app_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const CampuraApp());
}

class CampuraApp extends StatelessWidget {
  const CampuraApp({super.key});

  static final _fallbackLight = ColorScheme.fromSeed(
    seedColor: const Color(0xFF596FA9),
  );
  static final _fallbackDark = ColorScheme.fromSeed(
    seedColor: const Color(0xFF596FA9),
    brightness: Brightness.dark,
  );

  @override
  Widget build(BuildContext context) => DynamicColorBuilder(
    builder: (lightDynamic, darkDynamic) {
      final light = lightDynamic?.harmonized() ?? _fallbackLight;
      final dark = darkDynamic?.harmonized() ?? _fallbackDark;
      return MaterialApp(
        title: 'Campura One · 域校屿',
        debugShowCheckedModeBanner: false,
        locale: const Locale('zh', 'CN'),
        supportedLocales: const [Locale('zh', 'CN')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        themeMode: ThemeMode.system,
        theme: _theme(light),
        darkTheme: _theme(dark),
        home: const _StartupGate(),
      );
    },
  );

  ThemeData _theme(ColorScheme colors) => ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: colors.surface,
    appBarTheme: AppBarTheme(backgroundColor: colors.surface),
    cardTheme: CardThemeData(
      elevation: 0,
      color: colors.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: colors.surfaceContainer,
      indicatorColor: colors.secondaryContainer,
    ),
  );
}

class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 800), () {
      if (mounted) setState(() => ready = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final colors = Theme.of(context).colorScheme;
    return PageTransitionSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 150 : 550),
      transitionBuilder: (child, animation, secondaryAnimation) => reduceMotion
          ? FadeTransition(opacity: animation, child: child)
          : FadeThroughTransition(
              animation: CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ),
              secondaryAnimation: CurvedAnimation(
                parent: secondaryAnimation,
                curve: Curves.easeInCubic,
              ),
              fillColor: colors.surface,
              child: child,
            ),
      child: ready
          ? const AppShell(key: ValueKey('app'))
          : Scaffold(
              key: const ValueKey('startup'),
              body: SafeArea(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.layers_rounded,
                          size: 72,
                          color: colors.primary,
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Campura One',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ],
                    ),
                    Positioned(
                      bottom: 36,
                      child: Text(
                        '正在进入演示',
                        style: Theme.of(context).textTheme.bodySmall
                            ?.copyWith(color: colors.onSurfaceVariant),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
