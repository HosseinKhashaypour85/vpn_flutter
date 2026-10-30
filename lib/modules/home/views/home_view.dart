import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class VpnServer {
  VpnServer({
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
  static Color bg = Color(0xFF070B14);
  static Color bg2 = Color(0xFF0E1626);
  static Color card = Color(0xFF131E33);
  static Color cardLight = Color(0xFF1B2942);
  static Color green = Color(0xFF19C795);
  static Color greenSoft = Color(0xFF0F7A5C);
  static Color red = Color(0xFFEF5350);
  static Color textPrimary = Colors.white;
  static Color textSecondary = Color(0xB3FFFFFF);
  static Color textMuted = Color(0x66FFFFFF);

  static void applyTheme(String mode) {
    if (mode == 'light') {
      bg = Color(0xFFF4F6F8);
      bg2 = Color(0xFFE9EDF1);
      card = Colors.white;
      cardLight = Color(0xFFE4E9EE);
      green = Color(0xFF10706B);
      greenSoft = Color(0xFF0B5753);
      red = Color(0xFFD84343);
      textPrimary = Color(0xFF17212B);
      textSecondary = Color(0xFF46515C);
      textMuted = Color(0xFF7B8792);
    } else if (mode == 'mono') {
      bg = Color(0xFF000000);
      bg2 = Color(0xFF101010);
      card = Color(0xFF181818);
      cardLight = Color(0xFF292929);
      green = Colors.white;
      greenSoft = Color(0xFFBDBDBD);
      red = Color(0xFFE0E0E0);
      textPrimary = Colors.white;
      textSecondary = Color(0xFFE0E0E0);
      textMuted = Color(0xFF9E9E9E);
    } else {
      bg = Color(0xFF070B14);
      bg2 = Color(0xFF0E1626);
      card = Color(0xFF131E33);
      cardLight = Color(0xFF1B2942);
      green = Color(0xFF19C795);
      greenSoft = Color(0xFF0F7A5C);
      red = Color(0xFFEF5350);
      textPrimary = Colors.white;
      textSecondary = Color(0xB3FFFFFF);
      textMuted = Color(0x66FFFFFF);
    }
  }
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
  String _themeMode = 'dark';
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
      duration: Duration(seconds: 2),
    )..repeat();
    _entranceController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 700),
    )..forward();

    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        debugPrint('V2RAY STATUS: $status');
      },
    );
    _initializeVpn();
    _restoreSavedData();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _entranceController.dispose();
    super.dispose();
  }


  Future<void> _saveSubscriptions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('vpn_subscriptions', List<String>.from(_subscriptions));
    await prefs.setString('selected_vpn_server', _selectedLink ?? '');
    await prefs.setString('vpn_theme_mode', _themeMode);
  }

  Future<void> _restoreSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedTheme = prefs.getString('vpn_theme_mode') ?? 'dark';
    final savedUrls = prefs.getStringList('vpn_subscriptions') ?? [];
    final savedLink = prefs.getString('selected_vpn_server');

    AppColors.applyTheme(savedTheme);
    if (mounted) setState(() => _themeMode = savedTheme);

    for (final url in savedUrls) {
      await _loadSubscription(url, refresh: true, silent: true);
    }

    if (!mounted) return;
    setState(() {
      if (savedLink != null && savedLink.isNotEmpty &&
          _servers.any((server) => server.link == savedLink)) {
        _selectedLink = savedLink;
      }
    });
    await _saveSubscriptions();
  }

  Future<void> _showThemeSettings() async {
    final selectedMode = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, dialogSetState) => AlertDialog(
          backgroundColor: AppColors.card,
          title: Text('تنظیمات ظاهر', style: TextStyle(color: AppColors.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _themeOption(dialogSetState, 'dark', 'تیره', Icons.dark_mode_outlined),
              _themeOption(dialogSetState, 'light', 'روشن', Icons.light_mode_outlined),
              _themeOption(dialogSetState, 'mono', 'سیاه و سفید', Icons.contrast_rounded),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text('بستن', style: TextStyle(color: AppColors.green)),
            ),
          ],
        ),
      ),
    );

    if (selectedMode == null || !mounted) return;
    setState(() {
      _themeMode = selectedMode;
      AppColors.applyTheme(selectedMode);
    });
    await _saveSubscriptions();
  }

  Widget _themeOption(
    StateSetter dialogSetState,
    String value,
    String label,
    IconData icon,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: AppColors.green),
      title: Text(label, style: TextStyle(color: AppColors.textPrimary)),
      trailing: _themeMode == value
          ? Icon(Icons.check_circle_rounded, color: AppColors.green)
          : null,
      onTap: () {
        dialogSetState(() {});
        Navigator.pop(context, value);
      },
    );
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
      throw FormatException('لینک اشتراک باید با http:// یا https:// شروع شود.');
    }

    final response = await http
        .get(
          uri,
          headers: {
            'Accept': 'text/plain, */*',
            'Cache-Control': 'no-cache',
            'User-Agent': 'Mozilla/5.0 Flutter VPN Client',
          },
        )
        .timeout(const Duration(seconds: 25));

    debugPrint('SUBSCRIPTION HTTP: ${response.statusCode}');
    debugPrint(
      'SUBSCRIPTION CONTENT-TYPE: ${response.headers['content-type'] ?? 'unknown'}',
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('سرور اشتراک کد HTTP ${response.statusCode} برگرداند.');
    }

    final responseBody =
        utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (responseBody.isEmpty) {
      throw FormatException('سرور محتوای خالی برگرداند.');
    }

    // بعضی سرویس‌ها لینک‌ها را مستقیم و بعضی به‌صورت Base64/Base64URL می‌فرستند.
    // چند نمایش احتمالی محتوا را بررسی می‌کنیم و لینک‌ها را از داخل متن استخراج می‌کنیم.
    final candidates = <String>[responseBody];

    final urlDecoded = Uri.decodeComponent(responseBody);
    if (urlDecoded != responseBody) candidates.add(urlDecoded);

    final compact = responseBody.replaceAll(RegExp(r'\s+'), '');
    if (compact.length >= 8) {
      final normalized = compact
          .replaceAll('-', '+')
          .replaceAll('_', '/');
      final padded = normalized.padRight(
        normalized.length + ((4 - normalized.length % 4) % 4),
        '=',
      );

      try {
        final decoded = utf8.decode(
          base64.decode(padded),
          allowMalformed: true,
        ).trim();
        if (decoded.isNotEmpty) candidates.add(decoded);
      } catch (_) {
        // پاسخ ممکن است اصلاً Base64 نباشد.
      }
    }

    final linkPattern = RegExp(
      r'(?:vless|vmess|trojan|ss)://[^\s<>"\x27]+',
      caseSensitive: false,
    );
    final foundLinks = <String>{};

    for (final candidate in candidates) {
      for (final match in linkPattern.allMatches(candidate)) {
        var link = match.group(0)!.trim();
        link = link.replaceFirst(RegExp(r'[,;)\]}]+$'), '');
        if (link.isEmpty) continue;

        final lower = link.toLowerCase();
        if (lower.startsWith('vless://') ||
            lower.startsWith('vmess://') ||
            lower.startsWith('trojan://') ||
            lower.startsWith('ss://')) {
          foundLinks.add(link);
        }
      }

      if (foundLinks.isNotEmpty) break;
    }

    final links = foundLinks.toList();

    if (links.isEmpty) {
      final contentType = response.headers['content-type'] ?? '';
      if (contentType.contains('text/html') ||
          responseBody.toLowerCase().contains('<html')) {
        throw FormatException(
          'سرور به‌جای اشتراک، صفحه HTML برگرداند. احتمالاً لینک اشتراک یا دسترسی آن نیاز به بررسی دارد.',
        );
      }

      final preview = responseBody.length > 180
          ? '${responseBody.substring(0, 180)}...'
          : responseBody;
      debugPrint('SUBSCRIPTION BODY PREVIEW: $preview');
      throw FormatException(
        'پاسخ دریافت شد اما لینک کانفیگ پیدا نشد. فرمت خروجی اشتراک را بررسی کن.',
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
      return VpnServer(
        name: name,
        link: link,
        subscriptionUrl: rawUrl.trim(),
      );
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
          insetPadding: EdgeInsets.symmetric(horizontal: 22),
          child: Container(
            padding: EdgeInsets.all(22),
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
                      padding: EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.green.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.link_rounded,
                          color: AppColors.green, size: 22),
                    ),
                    SizedBox(width: 12),
                    Text(
                      'افزودن اشتراک',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'لینک اشتراک خود را وارد کنید تا سرورها به‌صورت خودکار استخراج شوند.',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    height: 1.6,
                  ),
                ),
                SizedBox(height: 18),
                TextField(
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  style: TextStyle(color: AppColors.textPrimary),
                  onChanged: (value) => input = value.trim(),
                  decoration: InputDecoration(
                    hintText: 'https://example.com/subscription',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    prefixIcon: Icon(Icons.public_rounded,
                        color: AppColors.textMuted, size: 20),
                    filled: true,
                    fillColor: AppColors.bg,
                    contentPadding: EdgeInsets.symmetric(
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
                      borderSide: BorderSide(
                        color: AppColors.green,
                        width: 1.4,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: AppColors.textMuted.withValues(alpha: 0.3),
                            ),
                          ),
                        ),
                        child: Text(
                          'لغو',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(dialogContext, input),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.green,
                          foregroundColor: AppColors.bg,
                          padding: EdgeInsets.symmetric(vertical: 14),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
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

  Future<void> _loadSubscription(String url, {bool refresh = false, bool silent = false}) async {
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

      await _saveSubscriptions();
      if (!silent) {
        _showMessage(
          refresh
              ? 'اشتراک به‌روزرسانی شد'
              : '${fetchedServers.length} سرور اضافه شد',
        );
      }
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
        duration: Duration(seconds: 5),
        backgroundColor: AppColors.cardLight,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: EdgeInsets.all(16),
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [AppColors.bg2, AppColors.bg],
            ),
          ),
          child: SafeArea(
            child: ListView(
              padding: EdgeInsets.fromLTRB(20, 18, 20, 30),
              children: [
                // ---------- هدر ----------
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
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
                      child: Icon(Icons.shield_rounded,
                          color: Colors.white, size: 26),
                    ),
                    SizedBox(width: 14),
                    Expanded(
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
                      icon: Icons.palette_outlined,
                      tooltip: 'تنظیمات تم',
                      onPressed: _showThemeSettings,
                    ),
                    SizedBox(width: 8),
                    _RoundActionButton(
                      icon: Icons.refresh_rounded,
                      tooltip: 'به‌روزرسانی اشتراک‌ها',
                      onPressed: _refreshSubscriptions,
                    ),
                  ],
                ),
                SizedBox(height: 26),

                // ---------- کارت اصلی اتصال ----------
                _buildConnectionCard(selected),
                SizedBox(height: 26),

                // ---------- بخش سرورها ----------
                Row(
                  children: [
                    Text(
                      'سرورها',
                      style: TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    if (_servers.isNotEmpty)
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 9, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.green.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${_servers.length}',
                          style: TextStyle(
                            color: AppColors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Spacer(),
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
                      icon: Icon(Icons.add_rounded, size: 26),
                    ),
                  ],
                ),
                SizedBox(height: 14),

                if (_servers.isEmpty)
                  _buildEmptyServers()
                else
                  ...List.generate(_servers.length, (index) {
                    final server = _servers[index];
                    return _buildServerTile(server, index);
                  }),

                if (selected != null) ...[
                  SizedBox(height: 10),
                  Container(
                    padding: EdgeInsets.symmetric(
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
                        Icon(Icons.check_circle_rounded,
                            color: AppColors.green, size: 18),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'سرور انتخاب‌شده: ${selected.name}',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          selected.link.split('://').first.toUpperCase(),
                          style: TextStyle(
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
      padding: EdgeInsets.fromLTRB(20, 26, 20, 24),
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
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          // وضعیت بالای کارت
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
                SizedBox(width: 8),
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
          SizedBox(height: 22),

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
                    duration: Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _connected
                          ? LinearGradient(
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
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _connecting
                          ? SizedBox(
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
          SizedBox(height: 18),

          Text(
            _connected
                ? 'اتصال برقرار است'
                : (_connecting ? 'در حال اتصال...' : 'برای اتصال ضربه بزنید'),
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _status,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textMuted,
              fontSize: 12,
              height: 1.6,
            ),
          ),
          SizedBox(height: 16),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
                SizedBox(width: 8),
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
      padding: EdgeInsets.symmetric(vertical: 36, horizontal: 20),
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
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.green.withValues(alpha: 0.08),
            ),
            child: Icon(Icons.dns_outlined,
                color: AppColors.green, size: 36),
          ),
          SizedBox(height: 16),
          Text(
            'هنوز سروری اضافه نشده',
            style: TextStyle(
              color: AppColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 6),
          Text(
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
      duration: Duration(milliseconds: 300),
      child: Container(
        margin: EdgeInsets.only(bottom: 10),
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
                : () async {
                    setState(() => _selectedLink = server.link);
                    await _saveSubscriptions();
                  },
            child: Padding(
              padding: EdgeInsets.symmetric(
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
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          server.name,
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
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
                  SizedBox(width: 10),
                  // نشانگر انتخاب
                  AnimatedContainer(
                    duration: Duration(milliseconds: 200),
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
                        ? Icon(Icons.check_rounded,
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
  _RoundActionButton({
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