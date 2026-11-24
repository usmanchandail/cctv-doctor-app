import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';

const _navy = Color(0xFF000000);
const _surface = Color(0xFF0A0A0A);
const _lime = Color(0xFFB7F000);
const _website = 'https://cctvdoctor.pk';
const _webPageChromeCleanupScript = r'''
(() => {
  const chromeSelectors = [
    'header',
    'nav',
    'footer',
    '[role="banner"]',
    '[role="navigation"]',
    '[role="contentinfo"]',
    '.site-header',
    '.site-footer',
    '.navbar',
    '.elementor-location-header',
    '.elementor-location-footer'
  ];
  const popupSelectors = [
    '[role="dialog"]',
    '[aria-modal="true"]',
    '.elementor-popup-modal',
    '[class*="cookie"]',
    '[id*="cookie"]',
    '[class*="consent"]',
    '[id*="consent"]',
    '[class*="newsletter"]',
    '[id*="newsletter"]',
    '[class*="popup"]',
    '[id*="popup"]',
    '[class*="modal"]',
    '[id*="modal"]',
    '[class*="promo-banner"]',
    '[id*="promo-banner"]',
    '[class*="ad-banner"]',
    '[id*="ad-banner"]'
  ];
  const popupPattern =
    /cookie|consent|newsletter|popup|modal|advert|promo-banner|ad-banner/i;
  const fixedPopupPattern =
    /cookie|consent|newsletter|popup|modal|advert|promo|banner|announcement|subscribe|offer/i;
  const floatingPattern =
    /floating|sticky|whatsapp|messenger|chat|tawk|crisp|intercom|quote[-_ ]?cta|contact[-_ ]?cta|call[-_ ]?cta/i;
  const actionPattern =
    /get\s*(?:a\s*)?quote|request\s*(?:a\s*)?quote|\bquote\b|\bcontact\b|call\s*(?:now|us)|\bphone\b|chat\s*(?:now|with us)?|whats?app|message\s*us|free\s*consultation/i;

  function hide(element) {
    if (!(element instanceof Element) || element === document.body ||
        element === document.documentElement) return;
    if (element.style.getPropertyValue('display') === 'none' &&
        element.style.getPropertyPriority('display') === 'important') return;
    element.style.setProperty('display', 'none', 'important');
    element.setAttribute('data-cctv-doctor-hidden', 'true');
  }

  function clean(root) {
    if (!root || !root.querySelectorAll) return;
    const matches = (selector) => {
      if (root instanceof Element && root.matches(selector)) hide(root);
      root.querySelectorAll(selector).forEach(hide);
    };
    chromeSelectors.forEach(matches);
    popupSelectors.forEach(matches);

    const candidates = [];
    if (root instanceof Element) candidates.push(root);
    candidates.push(...root.querySelectorAll(
      'a, button, iframe, [class], [id], [role], [aria-label], [title]'
    ));
    for (const element of candidates) {
      if (!(element instanceof Element)) continue;
      const classes = typeof element.className === 'string'
        ? element.className
        : '';
      const widgetIdentity = [
        element.id,
        classes,
        element.getAttribute('aria-label') || '',
        element.getAttribute('title') || ''
      ].join(' ');
      const identity = [
        widgetIdentity,
        element.getAttribute('href') || '',
        (element.innerText || '').slice(0, 180)
      ].join(' ');
      if (popupPattern.test(widgetIdentity) ||
          element.matches('[role="dialog"], [aria-modal="true"]')) {
        hide(element);
        continue;
      }

      const position = getComputedStyle(element).position;
      const isFixed = position === 'fixed' || position === 'sticky';
      const isButton = element.matches('a, button, iframe, [role="button"]');
      if (floatingPattern.test(widgetIdentity) ||
          (isFixed &&
              (fixedPopupPattern.test(identity) ||
                  (isButton && actionPattern.test(identity))))) {
        hide(element);
      }
    }
  }

  function cleanWithoutJump(root) {
    const pointY = Math.min(120, Math.max(0, window.innerHeight - 1));
    const anchor = document.elementFromPoint(window.innerWidth / 2, pointY);
    const anchorTop = anchor ? anchor.getBoundingClientRect().top : 0;
    clean(root);
    if (anchor && anchor.isConnected &&
        !anchor.closest('[data-cctv-doctor-hidden="true"]')) {
      const shift = anchor.getBoundingClientRect().top - anchorTop;
      if (Math.abs(shift) > 1) window.scrollBy(0, shift);
    }
  }

  cleanWithoutJump(document);
  window.setTimeout(() => cleanWithoutJump(document), 350);
  window.setTimeout(() => cleanWithoutJump(document), 1100);

  if (!window.__cctvDoctorCleanupObserver && document.documentElement) {
    window.__cctvDoctorCleanupObserver = new MutationObserver((records) => {
      for (const record of records) {
        if (record.type === 'childList') {
          record.addedNodes.forEach((node) => cleanWithoutJump(node));
        } else {
          cleanWithoutJump(record.target);
        }
      }
    });
    window.__cctvDoctorCleanupObserver.observe(document.documentElement, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ['class', 'id', 'role', 'aria-modal', 'style']
    });
  }
})();
''';

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
  int _selectedTab = 0;
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
          onPageFinished: (_) async {
            await _controller.runJavaScript(_webPageChromeCleanupScript);
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
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  const _AppHeader(),
                  SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: _progress / 100,
                      color: _lime,
                      backgroundColor: _surface,
                    ),
                  ),
                  Expanded(
                    child: _WebViewContent(
                      controller: _controller,
                      hasError: _hasError,
                      onRetry: _retry,
                    ),
                  ),
                ],
              ),
              IgnorePointer(
                ignoring: !_showSplash,
                child: AnimatedOpacity(
                  opacity: _showSplash ? 1 : 0,
                  duration: const Duration(milliseconds: 250),
                  child: ColoredBox(
                    color: _navy,
                    child: Center(
                      child: Image.asset('assets/square_icon.png', width: 140),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: _selectedTab,
          onTap: _navigateToTab,
          type: BottomNavigationBarType.fixed,
          backgroundColor: _surface,
          selectedItemColor: _lime,
          unselectedItemColor: Colors.white60,
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.videocam_rounded), label: 'Services'),
            BottomNavigationBarItem(icon: Icon(Icons.assignment_rounded), label: 'Get Quote'),
            BottomNavigationBarItem(icon: Icon(Icons.support_agent_rounded), label: 'Contact'),
          ],
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: const Color(0xFF25D366),
          foregroundColor: Colors.white,
          onPressed: _openWhatsApp,
          child: const FaIcon(FontAwesomeIcons.whatsapp, size: 30, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      ),
    );
  }

  Future<void> _navigateToTab(int index) async {
    setState(() => _selectedTab = index);
    const targets = <String?>[null, 'services', 'quote', 'contact'];
    if (index < 0 || index >= targets.length) return;

    final target = targets[index];
    final currentUrl = await _controller.currentUrl();
    final currentUri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    final isHomePage = currentUri != null &&
        (currentUri.host == 'cctvdoctor.pk' ||
            currentUri.host == 'www.cctvdoctor.pk') &&
        (currentUri.path.isEmpty || currentUri.path == '/');

    if (target == null) {
      if (isHomePage) {
        await _controller.runJavaScript('''
          if (window.location.hash) {
            window.history.replaceState(null, '', window.location.pathname + window.location.search);
          }
          window.scrollTo({ top: 0, behavior: 'smooth' });
        ''');
      } else {
        await _controller.loadRequest(Uri.parse('$_website/'));
      }
      return;
    }

    if (!isHomePage) {
      await _controller.loadRequest(Uri.parse('$_website/#$target'));
      return;
    }

    await _controller.runJavaScript('''
      (() => {
        const key = '$target';
        const normalized = (value) => value.toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
        const direct = document.getElementById(key) ||
          document.querySelector('[name="' + key + '"]');
        const idMatch = direct || Array.from(document.querySelectorAll('[id]'))
          .find((element) => normalized(element.id).includes(key));
        const keywords = {
          services: /service/i,
          quote: /quote|estimate/i,
          contact: /contact|get in touch|reach us/i
        };
        const heading = Array.from(document.querySelectorAll('h1, h2, h3, h4, h5, h6'))
          .find((element) => keywords[key].test(element.innerText || ''));
        const section = heading && heading.closest('section, article, [id]');
        const target = idMatch || section || heading;
        if (target) {
          target.scrollIntoView({ behavior: 'smooth', block: 'start' });
          window.history.replaceState(null, '', '#' + key);
        } else {
          window.location.hash = key;
        }
      })();
    ''');
  }

  Future<void> _openWhatsApp() async {
    final uri = Uri.parse('https://wa.me/923304455250');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
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
    required this.hasError,
    required this.onRetry,
  });

  final WebViewController controller;
  final bool hasError;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      bottom: false,
      child: hasError
          ? _ErrorView(onRetry: onRetry)
          : RefreshIndicator(
              onRefresh: controller.reload,
              child: WebViewWidget(controller: controller),
            ),
    );
  }
}

class _AppHeader extends StatelessWidget {
  const _AppHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      color: _surface,
      alignment: Alignment.center,
      child: Image.asset('assets/logo.png', height: 35),
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
