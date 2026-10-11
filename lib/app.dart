import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme.dart';
import 'features/onboarding/auth_screen.dart';
import 'features/onboarding/onboarding_screen.dart';
import 'features/onboarding/setup_screen.dart';
import 'features/shell/home_shell.dart';
import 'state/app_state.dart';
import 'widgets/common.dart';

class FormFlowApp extends StatelessWidget {
  final bool showSplash;
  const FormFlowApp({super.key, this.showSplash = true});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FormFlow',
      debugShowCheckedModeBanner: false,
      theme: FF.theme(),
      darkTheme: FF.theme(),
      themeMode: ThemeMode.dark,
      home: RootGate(showSplash: showSplash),
    );
  }
}

/// Splash -> onboarding -> sign in -> setup -> tabs (FR-AU-01).
class RootGate extends ConsumerStatefulWidget {
  final bool showSplash;
  const RootGate({super.key, this.showSplash = true});

  @override
  ConsumerState<RootGate> createState() => _RootGateState();
}

class _RootGateState extends ConsumerState<RootGate> {
  late bool _splash = widget.showSplash;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    if (_splash) {
      _timer = Timer(const Duration(milliseconds: 1400), () {
        if (mounted) setState(() => _splash = false);
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = ref.watch(appProvider);
    final d = app.data;
    Widget child;
    if (_splash) {
      child = const SplashScreen(key: ValueKey('splash'));
    } else if (!d.onboarded) {
      child = const OnboardingScreen(key: ValueKey('onboarding'));
    } else if (!d.signedIn) {
      child = const AuthScreen(key: ValueKey('auth'));
    } else if (d.benchmarkMs == null) {
      child = const SetupScreen(key: ValueKey('setup'));
    } else {
      child = const HomeShell(key: ValueKey('home'));
    }
    return AnimatedSwitcher(duration: const Duration(milliseconds: 300), child: child);
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.6, end: 1),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutBack,
          builder: (context, v, child) => Opacity(opacity: ((v - 0.6) / 0.4).clamp(0, 1).toDouble(), child: Transform.scale(scale: v, child: child)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(colors: [FF.accent, Color(0xFF4E8BFF)]),
                boxShadow: [BoxShadow(color: FF.accent.withValues(alpha: 0.5), blurRadius: 30)],
              ),
              child: const Icon(Icons.accessibility_new, size: 56, color: Colors.white),
            ),
            const SizedBox(height: 20),
            const FormFlowLogo(size: 36),
            const SizedBox(height: 8),
            const Text('Real-time form coaching', style: TextStyle(color: FF.muted)),
          ]),
        ),
      ),
    );
  }
}
