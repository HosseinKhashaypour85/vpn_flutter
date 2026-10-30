import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;

class VpnServer {
  const VpnServer({
    required this.name,
    required this.link,
    required this.subscriptionUrl,
  });

  final String name;
  final String link;
  final String subscriptionUrl;
}

// ---- پالت رنگی متمرکز برای هماهنگی کامل ----
class AppColors {
  static const Color bg = Color(0xFF070B14);
  static const Color bg2 = Color(0xFF0E1626);
  static const Color card = Color(0xFF131E33);
  static const Color cardLight = Color(0xFF1B2942);
  static const Color green = Color(0xFF19C795);
  static const Color greenSoft = Color(0xFF0F7A5C);
  static const Color red = Color(0xFFEF5350);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x66FFFFFF);
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with TickerProviderStateMixin {
  late final FlutterV2ray _v2ray;
  final List<String> _subscriptions = [];
  final List<VpnServer> _servers = [];

  String? _selectedLink;
  bool _initialized = false;
  bool _connecting = false;
  bool _connected = false;
  String _status = 'در حال آماده‌سازی موتور VPN...';

  // انیمیشن پالس دور دکمه اتصال
  late final AnimationController _pulseController;
  // انیمیشن ظاهر شدن تدریجی سرورها
  late final AnimationController _entranceController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        debugPrint('V2RAY STATUS: $status');
      },
    );
    _initializeVpn();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }

  Future<void> _initializeVpn() async {
    try {
      await _v2ray.initializeV2Ray();
      if (!mounted) return;
      setState(() {
        _initialized = true;
        _status = 'آماده اتصال';
      });
    } catch (e, st) {
      debugPrint('V2RAY INIT ERROR: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _status = 'راه‌اندازی موتور VPN ناموفق بود');
    }
  }

  Future<List<VpnServer>> _fetchSubscription(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !uri.hasAuthority ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      throw const FormatException('لینک اشتراک باید با http:// یا https:// شروع شود.');
    }

    final response = await http
        .get(uri, headers: const {'Accept': 'text/plain, */*'})
        .timeout(const Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('سرور اشتراک کد HTTP ${response.statusCode} برگرداند.');
    }

    var body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (body.isEmpty) throw const FormatException('محتوای اشتراک خالی است.');

    if (!body.contains('://')) {
      final compact = body.replaceAll(RegExp(r'\s+'), '');
      try {
        final decoded = utf8.decode(
          base64.decode(base64.normalize(compact)),
          allowMalformed: true,
        ).trim();
        if (decoded.contains('://')) {
          body = decoded;
        } else {
          try {
            final urlDecoded = utf8.decode(
              base64Url.decode(base64Url.normalize(compact)),
              allowMalformed: true,
            ).trim();
            if (urlDecoded.contains('://')) body = urlDecoded;
          } catch (_) {}
        }
      } catch (_) {
        try {
          final urlDecoded = utf8.decode(
            base64Url.decode(base64Url.normalize(compact)),
            allowMalformed: true,
          ).trim();
          if (urlDecoded.contains('://')) body = urlDecoded;
        } catch (_) {}
      }
    }

    final links = body
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.trim())
        .where((line) {
      final lower = line.toLowerCase();
      return lower.startsWith('vless://') ||
          lower.startsWith('vmess://') ||
          lower.startsWith('trojan://') ||
          lower.startsWith('ss://');
    })
        .toSet()
        .toList();

    if (links.isEmpty) {
      throw const FormatException(
        'هیچ کانفیگ VLESS، VMess، Trojan یا Shadowsocks در اشتراک پیدا نشد.',
      );
    }

    return List<VpnServer>.generate(links.length, (index) {
      final link = links[index];
      var name = 'سرور ${index + 1}';
      try {
        final parsed = FlutterV2ray.parseFromURL(link);
        if (parsed.remark.trim().isNotEmpty) name = parsed.remark.trim();
      } catch (e) {
        debugPrint('CONFIG PARSE WARNING: $e');
      }
      return VpnServer(name: name, link: link, subscriptionUrl: rawUrl.trim());
    });
  }

  Future<void> _addSubscription() async {
    var input = '';

    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppColors.green.withValues(alpha: 0.18),
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.green.withValues(alpha: 0.08),
                  blurRadius: 40,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.link_rounded,
                          color: AppColors.green, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'افزودن اشتراک',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'لینک اشتراک خود را وارد کنید تا سرورها به‌صورت خودکار استخراج شوند.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 18),
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  style: const TextStyle(color: AppColors.textPrimary),
                  onChanged: (value) => input = value.trim(),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/subscription',
                    hintStyle: const TextStyle(color: AppColors.textMuted),
                    prefixIcon: const Icon(Icons.public_rounded,
                        color: AppColors.textMuted, size: 20),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: AppColors.green.withValues(alpha: 0.12),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: AppColors.green,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.textMuted.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: const Text(
                          'لغو',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, input),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.bg,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'دریافت سرورها',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (!mounted || url == null || url.isEmpty) return;
    await _loadSubscription(url);
  }

  Future<void> _loadSubscription(String url, {bool refresh = false}) async {
    setState(() => _status = 'در حال دریافت اشتراک...');

    try {
      final fetchedServers = await _fetchSubscription(url);
      if (!mounted) return;

      setState(() {
        _subscriptions.remove(url);
        _subscriptions.add(url);
        _servers.removeWhere((server) => server.subscriptionUrl == url);
        _servers.addAll(fetchedServers);

        if (_selectedLink == null ||
            !_servers.any((server) => server.link == _selectedLink)) {
          _selectedLink = fetchedServers.first.link;
        }
        _status = '${fetchedServers.length} سرور دریافت شد';
      });

      _showMessage(
        refresh
            ? 'اشتراک به‌روزرسانی شد'
            : '${fetchedServers.length} سرور اضافه شد',
      );
    } catch (e, st) {
      debugPrint('SUBSCRIPTION ERROR: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _status = 'دریافت اشتراک ناموفق بود');
      _showMessage('خطا در دریافت اشتراک: $e');
    }
  }

  Future<void> _refreshSubscriptions() async {
    if (_subscriptions.isEmpty) {
      _showMessage('ابتدا روی + بزن و لینک اشتراک را اضافه کن');
      return;
    }

    for (final url in List<String>.from(_subscriptions)) {
      await _loadSubscription(url, refresh: true);
    }
  }

  Future<void> _toggleConnection() async {
    if (!_initialized || _connecting) return;

    setState(() => _connecting = true);
    try {
      if (_connected) {
        await _v2ray.stopV2Ray();
        if (!mounted) return;
        setState(() {
          _connected = false;
          _status = 'اتصال قطع شد';
        });
        return;
      }

      final selected = _servers.where((server) => server.link == _selectedLink);
      if (selected.isEmpty) {
        _showMessage('ابتدا از طریق دکمه + یک اشتراک اضافه و سرور انتخاب کن');
        return;
      }

      setState(() => _status = 'در حال درخواست اتصال...');
      final server = selected.first;
      final parsed = FlutterV2ray.parseFromURL(server.link);

      debugPrint('VPN CONNECT: selected server = ${server.name}');
      debugPrint('VPN CONNECT: protocol = ${server.link.split('://').first}');

      final hasPermission = await _v2ray.requestPermission();
      if (!hasPermission) {
        throw Exception('مجوز اتصال VPN صادر نشد');
      }

      await _v2ray.startV2Ray(
        remark: parsed.remark.isEmpty ? server.name : parsed.remark,
        config: parsed.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = 'درخواست اتصال ارسال شد؛ لاگ موتور را بررسی کن';
      });
    } catch (e, st) {
      debugPrint('VPN CONNECT ERROR: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() {
        _connected = false;
        _status = 'اتصال ناموفق بود؛ جزئیات در ترمینال است';
      });
      _showMessage('خطای اتصال: $e');
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 5),
        backgroundColor: AppColors.cardLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selectedServers =
    _servers.where((server) => server.link == _selectedLink).toList();
    final selected = selectedServers.isNotEmpty ? selectedServers.first : null;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bg2, AppColors.bg],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: [
                // ---------- هدر ----------
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.green, AppColors.greenSoft],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.3),
                            blurRadius: 18,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.shield_rounded,
                          color: Colors.white, size: 26),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Secure VPN',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'اتصال امن و خصوصی',
                            style: TextStyle(
                              color: AppColors.textMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _RoundActionButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'به‌روزرسانی اشتراک‌ها',
                      onPressed: _refreshSubscriptions,
                    ),
                  ],
                ),
                const SizedBox(height: 26),

                // ---------- کارت اصلی اتصال ----------
                _buildConnectionCard(selected),
                const SizedBox(height: 26),

                // ---------- بخش سرورها ----------
                Row(
                  children: [
                    const Text(
                      'سرورها',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_servers.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_servers.length}',
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const Spacer(),
                    IconButton.filled(
                      onPressed:
                      _connecting || _connected ? null : _addSubscription,
                      tooltip: 'افزودن لینک اشتراک',
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.green,
                        foregroundColor: AppColors.bg,
                        disabledBackgroundColor:
                        AppColors.green.withValues(alpha: 0.3),
                      ),
                      icon: const Icon(Icons.add_rounded, size: 26),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_servers.isEmpty)
                  _buildEmptyServers()
                else
                  ...List.generate(_servers.length, (index) {
                    final server = _servers[index];
                    return _buildServerTile(server, index);
                  }),

                if (selected != null) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: AppColors.green.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سرور انتخاب‌شده: ${selected.name}',
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          selected.link.split('://').first.toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.green,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------- کارت اتصال ----------
  Widget _buildConnectionCard(VpnServer? selected) {
    final ringColor = _connected ? AppColors.green : AppColors.textMuted;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 26, 20, 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _connected
              ? [
            AppColors.green.withValues(alpha: 0.16),
            AppColors.card,
          ]
              : [AppColors.card, AppColors.card],
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: _connected
              ? AppColors.green.withValues(alpha: 0.3)
              : AppColors.textMuted.withValues(alpha: 0.08),
        ),
        boxShadow: [
          BoxShadow(
            color: (_connected ? AppColors.green : Colors.black)
                .withValues(alpha: _connected ? 0.12 : 0.25),
            blurRadius: 30,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // وضعیت بالای کارت
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: (_connected ? AppColors.green : AppColors.textMuted)
                  .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _connected ? AppColors.green : AppColors.textMuted,
                    boxShadow: _connected
                        ? [
                      BoxShadow(
                        color: AppColors.green.withValues(alpha: 0.6),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ]
                        : [],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  _connected ? 'متصل' : 'قطع',
                  style: TextStyle(
                    color: _connected
                        ? AppColors.green
                        : AppColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // دکمه اتصال با پالس
          SizedBox(
            width: 190,
            height: 190,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (_connected)
                  ...List.generate(2, (i) {
                    return AnimatedBuilder(
                      animation: _pulseController,
                      builder: (context, child) {
                        final progress =
                            (_pulseController.value + i * 0.5) % 1.0;
                        return Container(
                          width: 150 + 40 * progress,
                          height: 150 + 40 * progress,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.green
                                  .withValues(alpha: 0.25 * (1 - progress)),
                              width: 2,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                GestureDetector(
                  onTap: _toggleConnection,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _connected
                          ? const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [AppColors.green, AppColors.greenSoft],
                      )
                          : LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.cardLight,
                          AppColors.card,
                        ],
                      ),
                      border: Border.all(color: ringColor, width: 2.5),
                      boxShadow: _connected
                          ? [
                        BoxShadow(
                          color: AppColors.green.withValues(alpha: 0.35),
                          blurRadius: 35,
                          spreadRadius: 4,
                        ),
                      ]
                          : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.3),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _connecting
                          ? const SizedBox(
                        width: 40,
                        height: 40,
                        child: CircularProgressIndicator(
                          color: AppColors.green,
                          strokeWidth: 3,
                        ),
                      )
                          : Icon(
                        _connected
                            ? Icons.shield_rounded
                            : Icons.power_settings_new_rounded,
                        size: 64,
                        color: _connected
                            ? Colors.white
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          Text(
            _connected
                ? 'اتصال برقرار است'
                : (_connecting ? 'در حال اتصال...' : 'برای اتصال ضربه بزنید'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.bg.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _initialized
                      ? Icons.check_circle_rounded
                      : Icons.hourglass_top_rounded,
                  color: _initialized
                      ? AppColors.green
                      : AppColors.textMuted,
                  size: 16,
                ),
                const SizedBox(width: 8),
                Text(
                  _initialized ? 'موتور VPN آماده است' : 'در حال آماده‌سازی موتور...',
                  style: TextStyle(
                    color: _initialized
                        ? AppColors.textSecondary
                        : AppColors.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------- کارت خالی ----------
  Widget _buildEmptyServers() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.textMuted.withValues(alpha: 0.08),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.green.withValues(alpha: 0.08),
            ),
            child: const Icon(Icons.dns_outlined,
                color: AppColors.green, size: 36),
          ),
          const SizedBox(height: 16),
          const Text(
            'هنوز سروری اضافه نشده',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'روی + بزن و لینک اشتراکت را وارد کن',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textMuted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ---------- ردیف سرور ----------
  Widget _buildServerTile(VpnServer server, int index) {
    final isSelected = server.link == _selectedLink;
    final protocol = server.link.split('://').first.toUpperCase();

    return AnimatedOpacity(
      opacity: 1,
      duration: const Duration(milliseconds: 300),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.green.withValues(alpha: 0.08)
              : AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected
                ? AppColors.green.withValues(alpha: 0.5)
                : AppColors.textMuted.withValues(alpha: 0.06),
            width: isSelected ? 1.4 : 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _connected || _connecting
                ? null
                : () => setState(() => _selectedLink = server.link),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              child: Row(
                children: [
                  // آیکون پروتکل
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isSelected
                            ? [AppColors.green, AppColors.greenSoft]
                            : [
                          AppColors.cardLight,
                          AppColors.card,
                        ],
                      ),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Center(
                      child: Text(
                        protocol.substring(0, 2),
                        style: TextStyle(
                          color: isSelected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.bg.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                protocol,
                                style: TextStyle(
                                  color: isSelected
                                      ? AppColors.green
                                      : AppColors.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  // نشانگر انتخاب
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.green : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.green
                            : AppColors.textMuted.withValues(alpha: 0.4),
                        width: 2,
                      ),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded,
                        color: Colors.white, size: 15)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- دکمه گرد هدر ----------
class _RoundActionButton extends StatelessWidget {
  const _RoundActionButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: AppColors.textMuted.withValues(alpha: 0.1),
        ),
      ),
      child: IconButton(
        onPressed: onPressed,
        tooltip: tooltip,
        icon: Icon(icon, color: AppColors.textSecondary, size: 22),
      ),
    );
  }
}