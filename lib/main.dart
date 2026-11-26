import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/providers.dart';
import 'app/router.dart';
import 'core/platform/host_bridge.dart';
import 'design_system/tokens/soft_tokens.dart';
import 'features/update/app_update_dialog.dart';
import 'features/update/app_update_service.dart';

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
  Timer? _autoUpdateTimer;
  CancelToken? _autoUpdateCancelToken;

  @override
  void initState() {
    super.initState();
    unawaited(
      ref.read(sourceRepositoryProvider).ensureBuiltinSourcesSeeded().catchError(
        (Object error, StackTrace stackTrace) {
          debugPrint('内置书源初始化异常: $error');
        },
      ),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _autoUpdateTimer = Timer(
        const Duration(seconds: 2),
        () => unawaited(_runSilentAutoUpdateCheck()),
      );
    });
  }

  Future<void> _runSilentAutoUpdateCheck() async {
    if (!mounted) return;
    final token = CancelToken();
    _autoUpdateCancelToken = token;
    try {
      final controller = ref.read(appUpdateControllerProvider.notifier);
      final result = await controller.checkAuto(cancelToken: token);
      if (!mounted || !result.hasUpdate || result.release == null) return;

      final navContext =
          ref.read(appRouterProvider).routerDelegate.navigatorKey.currentContext;
      if (navContext == null || !navContext.mounted) return;

      final service = ref.read(appUpdateServiceProvider);
      await showAppUpdateDialog(
        navContext,
        release: result.release!,
        currentVersion: result.currentVersion,
        service: service,
        supportsInAppApkInstall: service.supportsInAppApkInstall,
        onIgnored: () => controller.ignoreRelease(result.release!),
      );
    } catch (error) {
      debugPrint('启动静默检查更新忽略异常: $error');
    }
  }

  @override
  void dispose() {
    _autoUpdateTimer?.cancel();
    _autoUpdateTimer = null;
    _autoUpdateCancelToken?.cancel('app_disposed');
    _autoUpdateCancelToken = null;
    super.dispose();
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
