import 'dart:async';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

const _navy = Color(0xFF0A192F);
const _website = 'https://cctvdoctor.pk';

void main() {
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
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const WebViewHome()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/logo.png', width: 140, height: 140),
            const SizedBox(height: 24),
            const Text(
              'CCTV DOCTOR',
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 1.5),
            ),
            const SizedBox(height: 8),
            const Text('We Care For Your Security'),
            const SizedBox(height: 28),
            const CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class WebViewHome extends StatefulWidget {
  const WebViewHome({super.key});

  @override
  State<WebViewHome> createState() => _WebViewHomeState();
}

class _WebViewHomeState extends State<WebViewHome> {
  late final WebViewController _controller;
  int _progress = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (progress) => setState(() => _progress = progress),
          onPageStarted: (_) => setState(() {
            _hasError = false;
            _progress = 0;
          }),
          onPageFinished: (_) => setState(() => _progress = 100),
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
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('CCTV Doctor'),
          backgroundColor: _navy,
          bottom: _progress < 100
              ? PreferredSize(
                  preferredSize: const Size.fromHeight(3),
                  child: LinearProgressIndicator(value: _progress / 100),
                )
              : null,
        ),
        body: _hasError
            ? _ErrorView(onRetry: _retry)
            : RefreshIndicator(
                onRefresh: _controller.reload,
                child: WebViewWidget(controller: _controller),
              ),
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
