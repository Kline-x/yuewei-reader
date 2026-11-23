import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/platform/host_bridge.dart';
import 'design_system/tokens/soft_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  late final SharedPreferences prefs;
  await Future.wait([
    SharedPreferences.getInstance().then((p) => prefs = p),
    HostBridge.instance.initialize(),
  ]);

  runApp(
    ProviderScope(
      overrides: [
        sharedPrefsProvider.overrideWithValue(prefs),
      ],
      child: const YueweiApp(),
    ),
  );
}

class YueweiApp extends ConsumerStatefulWidget {
  const YueweiApp({super.key});

  @override
  ConsumerState<YueweiApp> createState() => _YueweiAppState();
}

class _YueweiAppState extends ConsumerState<YueweiApp> {
  @override
  void initState() {
    super.initState();
    ref.read(sourceRepositoryProvider).ensureBuiltinSourcesSeeded();
  }

  @override
  Widget build(BuildContext context) {
    final themeCfg = ref.watch(themeConfigProvider);
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: '阅微',
      debugShowCheckedModeBanner: false,
      routerConfig: router,
      themeMode: themeCfg.mode,
      theme: SoftTokens.resolve(themeCfg.palette, isDark: false).toThemeData(),
      darkTheme: SoftTokens.resolve(themeCfg.palette, isDark: true).toThemeData(),
      builder: (ctx, child) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final overlayStyle = (isDark
                ? SystemUiOverlayStyle.light
                : SystemUiOverlayStyle.dark)
            .copyWith(
          statusBarColor: Colors.transparent,
          systemNavigationBarColor: Colors.transparent,
        );
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: overlayStyle,
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
