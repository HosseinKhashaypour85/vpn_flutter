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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const Color bg = Color(0xFF0B1220);
  static const Color card = Color(0xFF151F30);
  static const Color green = Color(0xFF19C795);

  late final FlutterV2ray _v2ray;
  final List<String> _subscriptions = [];
  final List<VpnServer> _servers = [];
  final Map<String, int> _serverDelays = {};
  final Set<String> _pingingLinks = {};

  String? _selectedLink;
  bool _initialized = false;
  bool _connecting = false;
  bool _connected = false;
  bool _testingInternet = false;
  String _status = 'در حال آماده‌سازی موتور VPN...';
  String _trafficInfo = '';

  @override
  void initState() {
    super.initState();
    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        // Log actual engine state and traffic counters; do not infer a working
        // tunnel merely because startV2Ray() returned.
        debugPrint(
          'V2RAY STATUS: state=${status.state}, duration=${status.duration}, '
          'upload=${status.upload}, download=${status.download}, '
          'uploadSpeed=${status.uploadSpeed}, downloadSpeed=${status.downloadSpeed}',
        );
        if (!mounted) return;
        setState(() {
          _connected = status.state.toUpperCase() == 'CONNECTED';
          _trafficInfo =
              'آپلود: ${status.upload} B  •  دانلود: ${status.download} B';
          if (!_connected && !_connecting) {
            _status = 'موتور VPN متصل نیست (${status.state})';
          } else if (_connected) {
            _status = 'تونل فعال است؛ در حال بررسی عبور ترافیک';
          }
        });
      },
    );
    _initializeVpn();
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
      return VpnServer(
        name: name,
        link: link,
        subscriptionUrl: rawUrl.trim(),
      );
    });
  }

  Future<void> _addSubscription() async {
    // از TextEditingController محلی استفاده نمی‌کنیم تا هنگام خروج
    // انیمیشنی دیالوگ، controller پیش از TextField dispose نشود.
    var input = '';

    final url = await showDialog<String>(
      context: context,
      builder: (dialogContext) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: card,
          title: const Text(
            'افزودن اشتراک',
            style: TextStyle(color: Colors.white),
          ),
          content: TextField(
            autofocus: true,
            keyboardType: TextInputType.url,
            style: const TextStyle(color: Colors.white),
            onChanged: (value) => input = value.trim(),
            decoration: InputDecoration(
              hintText: 'https://example.com/subscription',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: bg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('لغو'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(dialogContext, input),
              style: ElevatedButton.styleFrom(
                backgroundColor: green,
                foregroundColor: bg,
              ),
              child: const Text('دریافت سرورها'),
            ),
          ],
        ),
      ),
    );

    if (!mounted || url == null || url.isEmpty) return;
    await _loadSubscription(url);
  }

  Future<void> _loadSubscription(
    String url, {
    bool refresh = false,
  }) async {
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

  Future<void> _pingServer(VpnServer server) async {
    if (_pingingLinks.contains(server.link)) return;

    setState(() {
      _pingingLinks.add(server.link);
      _serverDelays.remove(server.link);
    });

    try {
      final parsed = FlutterV2ray.parseFromURL(server.link);
      parsed.dns = {
        'servers': ['1.1.1.1', '8.8.8.8'],
      };
      final delay = await _v2ray
          .getServerDelay(config: parsed.getFullConfiguration())
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;
      setState(() => _serverDelays[server.link] = delay);
      debugPrint('VPN PING: ${server.name} = ${delay}ms');
    } catch (e, st) {
      debugPrint('VPN PING ERROR: ${server.name}: $e');
      debugPrintStack(stackTrace: st);
      if (!mounted) return;
      setState(() => _serverDelays[server.link] = -1);
      _showMessage('پینگ سرور ناموفق بود؛ کانفیگ یا دسترسی سرور را بررسی کن');
    } finally {
      if (mounted) {
        setState(() => _pingingLinks.remove(server.link));
      }
    }
  }

  Future<void> _testTunnelInternet() async {
    if (!_connected || _testingInternet) {
      _showMessage('ابتدا تونل VPN را وصل کن');
      return;
    }

    setState(() => _testingInternet = true);
    try {
      final response = await http
          .get(Uri.parse('https://www.google.com/generate_204'))
          .timeout(const Duration(seconds: 8));

      if (!mounted) return;
      if (response.statusCode == 204 || response.statusCode == 200) {
        setState(() => _status = 'تست اینترنت موفق بود (HTTP ${response.statusCode})');
        _showMessage('اینترنت از داخل اپ در دسترس است');
      } else {
        setState(() => _status = 'تست اینترنت: HTTP ${response.statusCode}');
        _showMessage('پاسخ غیرمنتظره از اینترنت: HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('VPN TUNNEL INTERNET TEST ERROR: $e');
      if (!mounted) return;
      setState(() => _status = 'تونل روشن است ولی تست اینترنت ناموفق بود');
      _showMessage('تست اینترنت ناموفق بود؛ لاگ: $e');
    } finally {
      if (mounted) setState(() => _testingInternet = false);
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

      // Use explicit public DNS resolvers instead of relying on the device DNS
      // configuration, which can fail inside some VPN tunnels.
      parsed.dns = {
        'servers': ['1.1.1.1', '8.8.8.8'],
      };
      parsed.log['loglevel'] = 'warning';

      debugPrint('VPN CONNECT: selected server = ${server.name}');
      debugPrint('VPN CONNECT: applying explicit DNS resolvers');
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
        _status = 'درخواست اتصال ارسال شد؛ منتظر وضعیت واقعی موتور هستیم';
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
      SnackBar(content: Text(message), duration: const Duration(seconds: 5)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final selected = _servers.where((server) => server.link == _selectedLink);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.shield_rounded, color: green, size: 28),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'VPN',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'اتصال امن و خصوصی',
                          style: TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _refreshSubscriptions,
                    tooltip: 'به‌روزرسانی اشتراک‌ها',
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Text(
                      _connected ? 'درخواست اتصال ارسال شد' : 'اتصال امن',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white60, fontSize: 13),
                    ),
                    const SizedBox(height: 28),
                    GestureDetector(
                      onTap: _toggleConnection,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: green.withValues(alpha: 0.07),
                          border: Border.all(
                            color: _connected ? green : Colors.white24,
                            width: 3,
                          ),
                          boxShadow: _connected
                              ? [
                                  BoxShadow(
                                    color: green.withValues(alpha: 0.18),
                                    blurRadius: 35,
                                    spreadRadius: 5,
                                  ),
                                ]
                              : [],
                        ),
                        child: Center(
                          child: _connecting
                              ? const CircularProgressIndicator(color: green)
                              : Icon(
                                  _connected
                                      ? Icons.shield_rounded
                                      : Icons.power_settings_new_rounded,
                                  size: 76,
                                  color: _connected ? green : Colors.white70,
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      _connected ? 'قطع اتصال' : 'اتصال به VPN',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _initialized ? 'موتور VPN آماده است' : 'در حال آماده‌سازی موتور...',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                    if (_trafficInfo.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        _trafficInfo,
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: !_connected || _testingInternet
                          ? null
                          : _testTunnelInternet,
                      icon: _testingInternet
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.public_rounded),
                      label: const Text('تست اینترنت از داخل تونل'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'سرورها و اشتراک‌ها',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton.filled(
                    onPressed: _connecting || _connected ? null : _addSubscription,
                    tooltip: 'افزودن لینک اشتراک',
                    style: IconButton.styleFrom(
                      backgroundColor: green,
                      foregroundColor: bg,
                    ),
                    icon: const Icon(Icons.add_rounded, size: 28),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (_servers.isEmpty)
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Column(
                    children: [
                      Icon(Icons.dns_outlined, color: Colors.white38, size: 38),
                      SizedBox(height: 10),
                      Text('هنوز سروری اضافه نشده', style: TextStyle(color: Colors.white)),
                      SizedBox(height: 6),
                      Text(
                        'روی + بزن و لینک اشتراکت را وارد کن',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ..._servers.map((server) {
                final isSelected = server.link == _selectedLink;
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? green : Colors.transparent,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    clipBehavior: Clip.antiAlias,
                    child: RadioListTile<String>(
                      value: server.link,
                      groupValue: _selectedLink,
                      onChanged: _connected || _connecting
                          ? null
                          : (value) => setState(() => _selectedLink = value),
                      activeColor: green,
                      title: Text(
                        server.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      subtitle: Text(
                        server.link.split('://').first.toUpperCase(),
                        style: const TextStyle(color: Colors.white54, fontSize: 11),
                      ),
                      secondary: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_pingingLinks.contains(server.link))
                            const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: green,
                              ),
                            )
                          else
                            Text(
                              _serverDelays.containsKey(server.link)
                                  ? (_serverDelays[server.link]! >= 0
                                      ? '${_serverDelays[server.link]} ms'
                                      : 'خطا')
                                  : '— ms',
                              style: TextStyle(
                                color: _serverDelays[server.link] != null &&
                                        _serverDelays[server.link]! >= 0
                                    ? green
                                    : Colors.white54,
                                fontSize: 11,
                              ),
                            ),
                          IconButton(
                            tooltip: 'تست پینگ',
                            onPressed: _pingingLinks.contains(server.link)
                                ? null
                                : () => _pingServer(server),
                            icon: const Icon(
                              Icons.speed_rounded,
                              color: green,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
              if (selected.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'سرور انتخاب‌شده: ${selected.first.name}',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
