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
  static Color bg = Color(0xFF071219);
  static Color bg2 = Color(0xFF0B2025);
  static Color card = Color(0xFF102B30);
  static Color cardLight = Color(0xFF194047);
  static Color green = Color(0xFF28D6A3);
  static Color greenSoft = Color(0xFF0C8A78);
  static Color red = Color(0xFFEF5350);
  static Color textPrimary = Colors.white;
  static Color textSecondary = Color(0xB3FFFFFF);
  static Color textMuted = Color(0x66FFFFFF);

  static void applyTheme(String mode) {
    if (mode == 'light') {
      bg = Color(0xFFF2F7F5);
      bg2 = Color(0xFFE5F0EC);
      card = Colors.white;
      cardLight = Color(0xFFE4E9EE);
      green = Color(0xFF087F70);
      greenSoft = Color(0xFF075B56);
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
      bg = Color(0xFF071219);
      bg2 = Color(0xFF0B2025);
      card = Color(0xFF102B30);
      cardLight = Color(0xFF194047);
      green = Color(0xFF28D6A3);
      greenSoft = Color(0xFF0C8A78);
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
  // Ping state: null means not tested, -1 means failed/unreachable.
  final Map<String, int> _serverPings = {};
  final Set<String> _pingingServers = <String>{};
  bool _pingingAll = false;

  static const String _pingTestUrl = 'https://www.gstatic.com/generate_204';

  Color _pingColor(int? ms) {
    if (ms == null) return AppColors.textMuted;
    if (ms < 0) return AppColors.red;
    if (ms <= 150) return AppColors.green;
    if (ms <= 300) return const Color(0xFFFFC857);
    return AppColors.red;
  }

  Future<int> _measureServerPing(VpnServer server) async {
    final parsed = FlutterV2ray.parseFromURL(server.link);
    return _v2ray.getServerDelay(
      config: parsed.getFullConfiguration(),
      url: _pingTestUrl,
    ).timeout(const Duration(seconds: 20));
  }

  Future<void> _pingSingleServer(VpnServer server) async {
    if (!_initialized || _pingingAll || _pingingServers.contains(server.link)) {
      return;
    }

    setState(() => _pingingServers.add(server.link));
    try {
      final delay = await _measureServerPing(server);
      if (!mounted) return;
      setState(() => _serverPings[server.link] = delay >= 0 ? delay : -1);
    } catch (e) {
      debugPrint('PING ERROR [${server.name}]: $e');
      if (!mounted) return;
      setState(() => _serverPings[server.link] = -1);
    } finally {
      if (mounted) setState(() => _pingingServers.remove(server.link));
    }
  }

  Future<void> _pingAllServers() async {
    if (!_initialized || _pingingAll || _pingingServers.isNotEmpty || _servers.isEmpty) {
      return;
    }

    setState(() {
      _pingingAll = true;
      _serverPings.clear();
    });

    try {
      // Limit concurrency to avoid overwhelming the device/core with many probes.
      const batchSize = 3;
      final servers = List<VpnServer>.from(_servers);
      for (var i = 0; i < servers.length; i += batchSize) {
        if (!mounted) return;
        final batch = servers.skip(i).take(batchSize).toList();
        setState(() {
          _pingingServers.addAll(batch.map((server) => server.link));
        });

        await Future.wait(batch.map((server) async {
          try {
            final delay = await _measureServerPing(server);
            if (!mounted) return;
            setState(() => _serverPings[server.link] = delay >= 0 ? delay : -1);
          } catch (e) {
            debugPrint('PING ERROR [${server.name}]: $e');
            if (!mounted) return;
            setState(() => _serverPings[server.link] = -1);
          } finally {
            if (mounted) {
              setState(() => _pingingServers.remove(server.link));
            }
          }
        }));
      }
    } finally {
      if (mounted) {
        setState(() {
          _pingingAll = false;
          _pingingServers.clear();
        });
      }
    }
  }


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

    await prefs.setStringList(
      'vpn_subscriptions',
      List<String>.from(_subscriptions),
    );

    await prefs.setString(
      'selected_vpn_server',
      _selectedLink ?? '',
    );

    await prefs.setString('vpn_theme_mode', _themeMode);

    // ذخیره خود کانفیگ سرورها برای استفاده آفلاین
    final cachedServers = _servers.map((server) {
      return {
        'name': server.name,
        'link': server.link,
        'subscriptionUrl': server.subscriptionUrl,
      };
    }).toList();

    await prefs.setString(
      'vpn_cached_servers',
      jsonEncode(cachedServers),
    );
  }

  Future<void> _restoreSavedData() async {
    final prefs = await SharedPreferences.getInstance();

    final savedTheme = prefs.getString('vpn_theme_mode') ?? 'dark';
    final savedUrls = prefs.getStringList('vpn_subscriptions') ?? [];
    final savedLink = prefs.getString('selected_vpn_server');
    final cachedJson = prefs.getString('vpn_cached_servers');

    AppColors.applyTheme(savedTheme);

    // ابتدا سرورهای ذخیره‌شده را بازیابی کن
    if (cachedJson != null) {
      try {
        final List<dynamic> cached = jsonDecode(cachedJson);

        final restoredServers = cached.map((item) {
          return VpnServer(
            name: item['name'],
            link: item['link'],
            subscriptionUrl: item['subscriptionUrl'],
          );
        }).toList();

        if (mounted) {
          setState(() {
            _themeMode = savedTheme;
            _servers
              ..clear()
              ..addAll(restoredServers);

            if (savedLink != null &&
                _servers.any((s) => s.link == savedLink)) {
              _selectedLink = savedLink;
            } else if (_servers.isNotEmpty) {
              _selectedLink = _servers.first.link;
            }

            _status = _servers.isNotEmpty
                ? '${_servers.length} سرور از حافظه بازیابی شد'
                : 'آماده اتصال';
          });
        }
      } catch (e) {
        debugPrint('CACHE RESTORE ERROR: $e');
      }
    } else if (mounted) {
      setState(() => _themeMode = savedTheme);
    }

    // سپس تلاش برای به‌روزرسانی از اینترنت
    for (final url in savedUrls) {
      await _loadSubscription(
        url,
        refresh: true,
        silent: true,
      );
    }

    if (!mounted) return;

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
        .get(uri, headers: {'Accept': 'text/plain, */*'})
        .timeout(Duration(seconds: 25));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      debugPrint('SUBSCRIPTION HTTP ERROR: ${response.statusCode}');
      debugPrint(
        'SUBSCRIPTION CONTENT-TYPE: ${response.headers['content-type']}',
      );
      debugPrint('SUBSCRIPTION ERROR BODY LENGTH: ${response.bodyBytes.length}');

      throw Exception('خطای سرور اشتراک: HTTP ${response.statusCode}');
    }

    var body = utf8.decode(response.bodyBytes, allowMalformed: true).trim();
    if (body.isEmpty) throw FormatException('محتوای اشتراک خالی است.');

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
      throw FormatException(
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

  Future<void> _loadSubscription(
      String url, {
        bool refresh = false,
        bool silent = false,
      }) async {
    if (mounted) {
      setState(() => _status = 'در حال دریافت اشتراک...');
    }

    try {
      final fetchedServers = await _fetchSubscription(url);

      if (!mounted) return;

      setState(() {
        _subscriptions.remove(url);
        _subscriptions.add(url);

        _servers.removeWhere(
              (server) => server.subscriptionUrl == url,
        );

        _servers.addAll(fetchedServers);

        if (_selectedLink == null ||
            !_servers.any((s) => s.link == _selectedLink)) {
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

      setState(() {
        _status = _servers.isNotEmpty
            ? 'استفاده از سرورهای ذخیره‌شده'
            : 'دریافت اشتراک ناموفق بود';
      });

      if (!silent) {
        _showMessage('خطا در دریافت اشتراک: $e');
      }
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
                      child: SimurghMark(size: 34, color: Colors.white),
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'سیمرغ VPN',
                            style: TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 23,
                              fontFamily: 'kalameh',
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'اتصال امن، آزاد و پایدار',
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
                else ...[
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'پینگ سرورها',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: _pingingAll || _pingingServers.isNotEmpty || !_initialized
                            ? null
                            : _pingAllServers,
                        icon: _pingingAll
                            ? SizedBox(
                                width: 15,
                                height: 15,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.green,
                                ),
                              )
                            : Icon(Icons.speed_rounded, size: 18),
                        label: Text(_pingingAll ? 'در حال تست...' : 'تست همه'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.green,
                        ),
                      ),
                    ],
                  ),
                  ...List.generate(_servers.length, (index) {
                    final server = _servers[index];
                    return _buildServerTile(server, index);
                  }),
                ],

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
                  _connected ? 'محافظت فعال' : 'آماده اتصال',
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

          // صحنه پرواز سیمرغ؛ پس از اتصال از مرکز به سمت بالا اوج می‌گیرد.
          SizedBox(
            height: 285,
            width: double.infinity,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.bottomCenter,
              children: [
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 1150),
                  curve: Curves.easeOutCubic,
                  top: _connected ? 0 : 125,
                  left: 0,
                  right: 0,
                  child: IgnorePointer(
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOut,
                      opacity: _connected ? 1 : 0,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 1150),
                        curve: Curves.easeOutBack,
                        scale: _connected ? 1 : 0.55,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.green.withValues(
                                    alpha: _connected ? 0.22 : 0,
                                  ),
                                  blurRadius: 48,
                                  spreadRadius: 8,
                                ),
                              ],
                            ),
                            child: SimurghMark(
                              size: 112,
                              color: AppColors.green,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // دکمه اتصال با پالس
                Positioned(
                  bottom: 0,
                  child: SizedBox(
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
                ),
              ],
            ),
          ),
          SizedBox(height: 18),

          Text(
            _connected
                ? 'سیمرغ از اتصال شما محافظت می‌کند'
                : (_connecting ? 'در حال برقراری اتصال...' : 'برای فعال‌سازی محافظت ضربه بزنید'),
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

  Widget _buildPingIndicator(VpnServer server) {
    final ping = _serverPings[server.link];
    final isLoading = _pingingServers.contains(server.link);

    return Container(
      constraints: const BoxConstraints(minWidth: 54),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
      decoration: BoxDecoration(
        color: _pingColor(ping).withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isLoading
            ? '...'
            : ping == null
                ? '--'
                : ping < 0
                    ? 'خطا'
                    : '${ping} ms',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _pingColor(ping),
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String? _countryFlagForServer(VpnServer server) {
    // اگر خود نام سرور از قبل ایموجی پرچم داشته باشد، همان را حفظ کن.
    final existingFlag = RegExp(r'[\\u{1F1E6}-\\u{1F1FF}]{2}', unicode: true)
        .firstMatch(server.name);
    if (existingFlag != null) return existingFlag.group(0);

    const aliases = <String, List<String>>{
      '🇩🇪': ['germany', 'deutschland', 'آلمان'],
      '🇳🇱': ['netherlands', 'holland', 'nl', 'هلند'],
      '🇫🇷': ['france', 'فرانسه'],
      '🇬🇧': ['uk', 'united kingdom', 'britain', 'england', 'انگلیس', 'بریتانیا'],
      '🇺🇸': ['usa', 'us', 'united states', 'america', 'آمریکا'],
      '🇨🇦': ['canada', 'کانادا'],
      '🇫🇮': ['finland', 'فنلاند'],
      '🇸🇪': ['sweden', 'سوئد'],
      '🇨🇭': ['switzerland', 'سوئیس'],
      '🇹🇷': ['turkey', 'turkiye', 'ترکیه'],
      '🇷🇺': ['russia', 'روسیه'],
      '🇯🇵': ['japan', 'ژاپن'],
      '🇸🇬': ['singapore', 'سنگاپور'],
      '🇦🇪': ['uae', 'emirates', 'امارات'],
      '🇮🇷': ['iran', 'ایران'],
      '🇵🇱': ['poland', 'لهستان'],
      '🇮🇹': ['italy', 'ایتالیا'],
      '🇪🇸': ['spain', 'اسپانیا'],
      '🇳🇴': ['norway', 'نروژ'],
      '🇩🇰': ['denmark', 'دانمارک'],
      '🇧🇪': ['belgium', 'بلژیک'],
      '🇦🇹': ['austria', 'اتریش'],
      '🇷🇴': ['romania', 'رومانی'],
      '🇨🇿': ['czech', 'جمهوری چک'],
      '🇭🇰': ['hong kong', 'هنگ کنگ'],
      '🇰🇷': ['south korea', 'korea', 'کره جنوبی'],
      '🇧🇷': ['brazil', 'برزیل'],
      '🇮🇳': ['india', 'هند'],
      '🇦🇺': ['australia', 'استرالیا'],
    };

    final name = server.name.toLowerCase();
    final host = Uri.tryParse(server.link)?.host.toLowerCase() ?? '';
    final searchable = '$name $host'.replaceAll(RegExp(r'[_]+'), ' ');

    for (final entry in aliases.entries) {
      for (final alias in entry.value) {
        // کدهای دوحرفی فقط به‌صورت توکن مستقل یا همراه شماره پذیرفته می‌شوند.
        final pattern = alias.length == 2
            ? RegExp('(^|[\\s._-])${RegExp.escape(alias)}([\\s._-]|[0-9]|$)', caseSensitive: false)
            : RegExp('(^|[^a-z0-9])${RegExp.escape(alias)}([^a-z0-9]|$)', caseSensitive: false);
        if (pattern.hasMatch(searchable)) return entry.key;
      }
    }
    return null;
  }

  Widget _buildServerTile(VpnServer server, int index) {
    final isSelected = server.link == _selectedLink;
    final protocol = server.link.split('://').first.toUpperCase();
    final countryFlag = _countryFlagForServer(server);

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
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                server.name,
                                style: TextStyle(
                                  color: AppColors.textPrimary,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (countryFlag != null) ...[
                              SizedBox(width: 8),
                              Text(countryFlag, style: TextStyle(fontSize: 19)),
                            ],
                          ],
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
                  SizedBox(width: 8),
                  _buildPingIndicator(server),
                  SizedBox(width: 4),
                  IconButton(
                    tooltip: 'تست پینگ این سرور',
                    onPressed: !_initialized || _pingingAll || _pingingServers.contains(server.link)
                        ? null
                        : () => _pingSingleServer(server),
                    icon: _pingingServers.contains(server.link)
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.green,
                            ),
                          )
                        : Icon(
                            Icons.refresh_rounded,
                            size: 19,
                            color: AppColors.textSecondary,
                          ),
                  ),
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


/// نشان اختصاصی سیمرغ؛ نماد پرواز، آزادی و محافظت.
class SimurghMark extends StatelessWidget {
  const SimurghMark({
    super.key,
    this.size = 48,
    this.color = const Color(0xFF28D6A3),
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _SimurghPainter(color),
      ),
    );
  }
}

class _SimurghPainter extends CustomPainter {
  _SimurghPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path()
      // بال چپ
      ..moveTo(size.width * .50, size.height * .20)
      ..cubicTo(size.width * .39, size.height * .16,
          size.width * .22, size.height * .12,
          size.width * .07, size.height * .27)
      ..cubicTo(size.width * .13, size.height * .31,
          size.width * .20, size.height * .39,
          size.width * .25, size.height * .52)
      ..cubicTo(size.width * .32, size.height * .47,
          size.width * .39, size.height * .48,
          size.width * .46, size.height * .62)
      // دم و تنه
      ..cubicTo(size.width * .45, size.height * .75,
          size.width * .48, size.height * .85,
          size.width * .50, size.height * .91)
      ..cubicTo(size.width * .52, size.height * .85,
          size.width * .55, size.height * .75,
          size.width * .54, size.height * .62)
      // بال راست
      ..cubicTo(size.width * .61, size.height * .48,
          size.width * .68, size.height * .47,
          size.width * .75, size.height * .52)
      ..cubicTo(size.width * .80, size.height * .39,
          size.width * .87, size.height * .31,
          size.width * .93, size.height * .27)
      ..cubicTo(size.width * .78, size.height * .12,
          size.width * .61, size.height * .16,
          size.width * .50, size.height * .20)
      ..close();

    canvas.drawPath(path, paint);

    final inner = Paint()
      ..color = color.withValues(alpha: .72)
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .035
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;

    final feather = Path()
      ..moveTo(size.width * .17, size.height * .31)
      ..quadraticBezierTo(size.width * .31, size.height * .29,
          size.width * .43, size.height * .53)
      ..moveTo(size.width * .83, size.height * .31)
      ..quadraticBezierTo(size.width * .69, size.height * .29,
          size.width * .57, size.height * .53)
      ..moveTo(size.width * .50, size.height * .27)
      ..lineTo(size.width * .50, size.height * .77);

    canvas.drawPath(feather, inner);
  }

  @override
  bool shouldRepaint(covariant _SimurghPainter oldDelegate) =>
      oldDelegate.color != color;
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