import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _navy = Color(0xFF000000);
const _website = 'https://cctvdoctor.pk';

void main() {
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF000000),
      statusBarIconBrightness: Brightness.light,
    ),
  );
  runApp(const CctvDoctorApp());
}

class CctvDoctorApp extends StatelessWidget {
  const CctvDoctorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CCTV Doctor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: _navy, brightness: Brightness.dark),
        scaffoldBackgroundColor: _navy,
        useMaterial3: true,
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  late final WebViewController _controller;
  Timer? _splashTimer;
  int _progress = 0;
  bool _hasError = false;
  bool _showSplash = true;

  @override
  void initState() {
    super.initState();

    late final PlatformWebViewControllerCreationParams params;
    if (WebViewPlatform.instance is AndroidWebViewPlatform) {
      params = AndroidWebViewControllerCreationParams
          .fromPlatformWebViewControllerCreationParams(
        const PlatformWebViewControllerCreationParams(),
      );
    } else {
      params = const PlatformWebViewControllerCreationParams();
    }

    _controller = WebViewController.fromPlatformCreationParams(params)
      ..setBackgroundColor(const Color(0xFF000000))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageStarted: (_) => setState(() {
            _hasError = false;
            _progress = 0;
          }),
          onPageFinished: (_) {
            setState(() => _progress = 100);
            _hideSplash();
          },
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) {
              setState(() => _hasError = true);
            }
          },
          onNavigationRequest: (request) async {
            final uri = Uri.tryParse(request.url);
            if (uri != null && _isExternalLink(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationDecision.prevent;
            }
            return NavigationDecision.navigate;
          },
        ),
      )
      ..loadRequest(Uri.parse(_website));

    _splashTimer = Timer(const Duration(milliseconds: 1200), _hideSplash);
  }

  void _hideSplash() {
    if (mounted && _showSplash) {
      _splashTimer?.cancel();
      _splashTimer = null;
      setState(() => _showSplash = false);
    }
  }

  bool _isExternalLink(Uri uri) {
    if (uri.scheme == 'tel' || uri.scheme == 'mailto' || uri.scheme == 'whatsapp') {
      return true;
    }
    final host = uri.host.toLowerCase();
    return host == 'wa.me' ||
        host.endsWith('.wa.me') ||
        host == 'facebook.com' ||
        host.endsWith('.facebook.com') ||
        host == 'instagram.com' ||
        host.endsWith('.instagram.com');
  }

  Future<void> _retry() async {
    setState(() => _hasError = false);
    await _controller.reload();
  }

  Future<bool> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
      return false;
    }
    if (!mounted) return true;
    final shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Exit App?'),
        content: const Text('Are you sure you want to exit?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Exit')),
        ],
      ),
    );
    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop && await _handleBack() && context.mounted) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            _WebViewContent(
              controller: _controller,
              progress: _progress,
              hasError: _hasError,
              onRetry: _retry,
            ),
            IgnorePointer(
              ignoring: !_showSplash,
              child: AnimatedOpacity(
                opacity: _showSplash ? 1 : 0,
                duration: const Duration(milliseconds: 250),
                child: ColoredBox(
                  color: _navy,
                  child: Center(
                    child: Image.asset('assets/logo.png', width: 220),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _splashTimer?.cancel();
    super.dispose();
  }
}

class _WebViewContent extends StatelessWidget {
  const _WebViewContent({
    required this.controller,
    required this.progress,
    required this.hasError,
    required this.onRetry,
  });

  final WebViewController controller;
  final int progress;
  final bool hasError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          if (progress < 100)
            SizedBox(
              height: 3,
              child: LinearProgressIndicator(value: progress / 100),
            ),
          Expanded(
            child: hasError
                ? _ErrorView(onRetry: onRetry)
                : RefreshIndicator(
                    onRefresh: controller.reload,
                    child: WebViewWidget(controller: controller),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.onRetry});

  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.wifi_off, size: 64),
          const SizedBox(height: 16),
          const Text('No Internet Connection', style: TextStyle(fontSize: 20)),
          const SizedBox(height: 16),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
