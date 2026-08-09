// MAYA — App Root Widget
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maya_app/app/router.dart';
import 'package:maya_app/app/theme.dart';
import 'package:maya_app/features/auth/domain/auth_provider.dart';

class MayaApp extends ConsumerStatefulWidget {
  const MayaApp({super.key});

  @override
  ConsumerState<MayaApp> createState() => _MayaAppState();
}

class _MayaAppState extends ConsumerState<MayaApp> {
  @override
  void initState() {
    super.initState();
    // Check for existing auth token on startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).checkAuth();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'MAYA',
      debugShowCheckedModeBanner: false,
      theme: MayaTheme.dark,
      routerConfig: router,
    );
  }
}
