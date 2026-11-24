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
    '.elementor-location-footer',
    '[class*="mobile-menu" i]',
    '[id*="mobile-menu" i]',
    '[class*="menu-drawer" i]',
    '[id*="menu-drawer" i]',
    '[class*="menu-overlay" i]',
    '[id*="menu-overlay" i]',
    '[class*="drawer-overlay" i]',
    '[id*="drawer-overlay" i]',
    '[class*="offcanvas" i]',
    '[id*="offcanvas" i]',
    '.elementor-menu-toggle',
    '.elementor-nav-menu--dropdown'
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
  const topBarSelectors = [
    'header',
    'nav',
    '[role="banner"]',
    '[role="navigation"]',
    '[class*="header" i]',
    '[id*="header" i]',
    '[class*="navbar" i]',
    '[id*="navbar" i]',
    '[class*="navigation" i]',
    '[id*="navigation" i]',
    '[class*="menu" i]',
    '[id*="menu" i]',
    '[class*="nav" i]',
    '[id*="nav" i]',
    '[class*="topbar" i]',
    '[id*="topbar" i]'
  ].join(',');
  const cleanupSelectors = [...chromeSelectors, ...popupSelectors].join(',');
  const staticCleanupSelectors = [
    cleanupSelectors,
    'a[href*="wa.me"]',
    'a[href*="whatsapp"]',
    '[class*="floating" i]',
    '[id*="floating" i]',
    '[class*="sticky-widget" i]',
    '[id*="sticky-widget" i]'
  ].join(',');
  const chromeStyle = document.createElement('style');
  chromeStyle.id = 'cctv-doctor-web-chrome-cleanup';
  chromeStyle.textContent =
      staticCleanupSelectors +
      '{display:none!important;visibility:hidden!important;pointer-events:none!important}';
  if (!document.getElementById(chromeStyle.id)) {
    (document.head || document.documentElement).appendChild(chromeStyle);
  }
  const popupPattern =
    /cookie|consent|newsletter|popup|modal|advert|promo-banner|ad-banner/i;
  const fixedPopupPattern =
    /cookie|consent|newsletter|popup|modal|advert|promo|banner|announcement|subscribe|offer/i;
  const floatingPattern =
    /floating|sticky|whatsapp|messenger|chat|tawk|crisp|intercom|quote[-_ ]?cta|contact[-_ ]?cta|call[-_ ]?cta/i;
  const topBarPattern = /header|nav|menu|top[-_ ]?bar|masthead/i;
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
    if (root instanceof Element && root.matches(cleanupSelectors)) hide(root);
    root.querySelectorAll(cleanupSelectors).forEach(hide);

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
        element.getAttribute('href') || ''
      ].join(' ');
      if (popupPattern.test(widgetIdentity) ||
          element.matches('[role="dialog"], [aria-modal="true"]')) {
        hide(element);
        continue;
      }

      if (floatingPattern.test(widgetIdentity)) {
        hide(element);
        continue;
      }

      const isButton = element.matches('a, button, iframe, [role="button"]');
      const buttonIdentity = isButton
        ? `${identity} ${(element.textContent || '').slice(0, 180)}`
        : identity;
      const mayBeFixedPopup = fixedPopupPattern.test(buttonIdentity) ||
          (isButton && actionPattern.test(buttonIdentity));
      if (mayBeFixedPopup) {
        const position = getComputedStyle(element).position;
        if (position === 'fixed' || position === 'sticky') hide(element);
      }
    }

    const topBars = [];
    if (root instanceof Element && root.matches(topBarSelectors)) {
      topBars.push(root);
    }
    topBars.push(...root.querySelectorAll(topBarSelectors));
    for (const element of topBars) {
      if (element === document.body ||
          element === document.documentElement ||
          element.hasAttribute('data-cctv-doctor-hidden')) {
        continue;
      }
      const identity = [
        element.tagName,
        element.id,
        typeof element.className === 'string' ? element.className : '',
        element.getAttribute('role') || '',
        element.getAttribute('aria-label') || ''
      ].join(' ');
      if (!topBarPattern.test(identity)) continue;

      const rect = element.getBoundingClientRect();
      if (rect.top >= -12 &&
          rect.top <= 12 &&
          rect.width >= window.innerWidth * 0.9 &&
          rect.height > 0 &&
          rect.height < 140) {
        const position = getComputedStyle(element).position;
        if (position !== 'fixed' && position !== 'sticky') continue;
        if (element.matches('main, [role="main"]') ||
            element.querySelector('main, [role="main"]')) {
          continue;
        }
        hide(element);
      }
    }
  }

  function cleanRootsWithoutJump(roots) {
    const pointY = Math.min(120, Math.max(0, window.innerHeight - 1));
    const anchor = document.elementFromPoint(window.innerWidth / 2, pointY);
    const anchorTop = anchor ? anchor.getBoundingClientRect().top : 0;
    roots.forEach(clean);
    if (anchor && anchor.isConnected &&
        !anchor.closest('[data-cctv-doctor-hidden="true"]')) {
      const shift = anchor.getBoundingClientRect().top - anchorTop;
      if (Math.abs(shift) > 1) window.scrollBy(0, shift);
    }
  }

  const cleanWithoutJump = (root) => cleanRootsWithoutJump([root]);
  cleanWithoutJump(document);

  if (!window.__cctvDoctorCleanupObserver && document.documentElement) {
    const pendingRoots = new Set();
    let cleanupTimer = null;
    const scheduleCleanup = (root) => {
      if (!root || !root.querySelectorAll || pendingRoots.has(document)) return;
      if (pendingRoots.size >= 12) {
        pendingRoots.clear();
        pendingRoots.add(document);
      } else {
        pendingRoots.add(root);
      }
      if (cleanupTimer !== null) return;
      cleanupTimer = window.setTimeout(() => {
        cleanupTimer = null;
        const roots = Array.from(pendingRoots);
        pendingRoots.clear();
        cleanRootsWithoutJump(roots);
      }, 80);
    };
    window.__cctvDoctorCleanupObserver = new MutationObserver((records) => {
      for (const record of records) {
        if (record.type === 'childList') {
          record.addedNodes.forEach(scheduleCleanup);
        } else if (record.attributeName !== 'style' ||
            !record.target.hasAttribute('data-cctv-doctor-hidden')) {
          scheduleCleanup(record.target);
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
  String? _pendingTabTarget;
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
          onProgress: (progress) {
            setState(() => _progress = progress);
            if (progress > 0) _hideSplash();
          },
          onPageStarted: (_) => setState(() {
            _hasError = false;
            _progress = 0;
          }),
          onPageFinished: (_) {
            _hideSplash();
            setState(() => _progress = 100);
            final pendingTarget = _pendingTabTarget;
            _pendingTabTarget = null;
            unawaited(_runPageFinishedTasks(pendingTarget));
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

  Future<void> _runPageFinishedTasks(String? pendingTarget) async {
    await _controller.runJavaScript(_webPageChromeCleanupScript);
    if (pendingTarget != null) {
      await _scrollToTab(pendingTarget == 'home' ? null : pendingTarget);
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
        bottomNavigationBar: NavigationBarTheme(
          data: NavigationBarThemeData(
            indicatorColor: const Color(0xFF050505),
            iconTheme: WidgetStateProperty.resolveWith(
              (states) => IconThemeData(
                color: states.contains(WidgetState.selected) ? _lime : Colors.white60,
              ),
            ),
            labelTextStyle: WidgetStateProperty.resolveWith(
              (states) => TextStyle(
                color: states.contains(WidgetState.selected) ? _lime : Colors.white60,
                fontWeight: states.contains(WidgetState.selected)
                    ? FontWeight.w600
                    : FontWeight.normal,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _selectedTab,
            onDestinationSelected: _navigateToTab,
            backgroundColor: _surface,
            indicatorColor: const Color(0xFF050505),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Home'),
              NavigationDestination(icon: Icon(Icons.videocam_rounded), label: 'Services'),
              NavigationDestination(icon: Icon(Icons.assignment_rounded), label: 'Get Quote'),
              NavigationDestination(icon: Icon(Icons.support_agent_rounded), label: 'Contact'),
            ],
          ),
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
    const targets = <String?>[null, 'services', 'quote', 'contact'];
    if (index < 0 || index >= targets.length) return;
    setState(() => _selectedTab = index);

    final target = targets[index];
    final currentUrl = await _controller.currentUrl();
    final currentUri = currentUrl == null ? null : Uri.tryParse(currentUrl);
    final isHomePage = currentUri != null &&
        (currentUri.host == 'cctvdoctor.pk' ||
            currentUri.host == 'www.cctvdoctor.pk') &&
        (currentUri.path.isEmpty || currentUri.path == '/');

    if (target == null) {
      if (isHomePage) {
        await _scrollToTab(null);
      } else {
        _pendingTabTarget = 'home';
        await _controller.loadRequest(Uri.parse('$_website/'));
      }
      return;
    }

    if (!isHomePage) {
      _pendingTabTarget = target;
      await _controller.loadRequest(Uri.parse('$_website/#$target'));
      return;
    }

    await _scrollToTab(target);
  }

  Future<void> _scrollToTab(String? target) async {
    if (target == null) {
      await _controller.runJavaScript('''
        if (window.location.hash) {
          window.history.replaceState(null, '', window.location.pathname + window.location.search);
        }
        window.scrollTo({ top: 0, behavior: 'smooth' });
      ''');
      return;
    }

    await _controller.runJavaScript('''
      (() => {
        const key = '$target';
        const aliases = {
          services: ['service', 'services'],
          quote: ['quote', 'estimate'],
          contact: ['contact', 'get in touch', 'reach us']
        };
        const normalize = (value) =>
          (value || '').toLowerCase().replace(/[^a-z0-9]+/g, ' ').trim();
        const rank = (value) => {
          const normalized = normalize(value);
          if (!normalized) return 0;
          if (aliases[key].includes(normalized)) return 100;
          const alias = aliases[key].find((item) => normalized.includes(item));
          if (!alias) return 0;
          return 50 + alias.length;
        };
        const isUsable = (element) =>
          !element.closest('[data-cctv-doctor-hidden], [hidden], [aria-hidden="true"]');
        const matches = (selector) =>
          Array.from(document.querySelectorAll(selector)).filter(isUsable);
        const candidates = new Map();
        const addCandidate = (element, score) => {
          if (!element || score <= 0 || !isUsable(element)) return;
          const current = candidates.get(element) || 0;
          if (score > current) candidates.set(element, score);
        };

        const identified = matches(
          '[id], [name], [data-section], [data-section-id], [data-anchor], ' +
          '[data-target], [data-page], [data-nav], [data-menu], [data-id], [data-name]'
        );
        for (const element of identified) {
          const idScore = rank(element.id);
          const nameScore = rank(element.getAttribute('name'));
          if (idScore) addCandidate(element, 300 + idScore);
          if (nameScore) addCandidate(element, 290 + nameScore);
          for (const attribute of element.attributes) {
            if (attribute.name.startsWith('data-')) {
              const dataScore = rank(attribute.value);
              if (dataScore) addCandidate(element, 250 + dataScore);
            }
          }
        }

        for (const heading of matches('h1, h2, h3, h4, h5, h6')) {
          const headingScore = rank(heading.textContent);
          if (!headingScore) continue;
          const section = heading.closest(
            'section, article, [id], [data-section], .elementor-section'
          );
          addCandidate(section || heading, 200 + headingScore);
        }

        for (const control of matches('a[href], button, [role="button"]')) {
          const label = [
            control.textContent || '',
            control.getAttribute('aria-label') || '',
            control.getAttribute('title') || '',
            control.getAttribute('href') || ''
          ].join(' ');
          const labelScore = rank(label);
          if (labelScore) addCandidate(control, 150 + labelScore);

          if (!control.matches('a[href]')) continue;
          try {
            const url = new URL(control.href, window.location.href);
            if (url.origin !== window.location.origin || !url.hash) continue;
            const hashScore = rank(decodeURIComponent(url.hash.slice(1)));
            if (!hashScore) continue;
            const target = document.getElementById(
              decodeURIComponent(url.hash.slice(1))
            );
            addCandidate(target || control, 280 + hashScore);
          } catch (_) {
            continue;
          }
        }

        let destination = null;
        let bestScore = 0;
        for (const [element, score] of candidates) {
          if (score > bestScore) {
            destination = element;
            bestScore = score;
          }
        }
        if (destination) {
          destination.scrollIntoView({ behavior: 'smooth', block: 'start' });
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
