
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_v2ray/flutter_v2ray.dart';

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
  final TextEditingController _configController =
  TextEditingController();

  bool _initialized = false;
  bool _connecting = false;
  bool _connected = false;
  String _status = 'آماده اتصال';

  @override
  void initState() {
    super.initState();

    _v2ray = FlutterV2ray(
      onStatusChanged: (status) {
        // وضعیت موتور VPN در صورت نیاز اینجا مدیریت می‌شود.
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
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _status = 'راه‌اندازی موتور VPN ناموفق بود';
      });
    }
  }

  Future<void> _toggleConnection() async {
    if (_connecting || !_initialized) return;

    if (_connected) {
      setState(() {
        _connecting = true;
      });

      try {
        await _v2ray.stopV2Ray();

        if (!mounted) return;
        setState(() {
          _connected = false;
          _status = 'اتصال قطع شد';
        });
      } catch (e) {
        if (!mounted) return;
        setState(() {
          _status = 'قطع اتصال ناموفق بود';
        });
      } finally {
        if (mounted) {
          setState(() => _connecting = false);
        }
      }
      return;
    }

    final link = _configController.text.trim();

    if (link.isEmpty) {
      _showMessage('ابتدا لینک کانفیگ سرور را وارد کن');
      return;
    }

    setState(() {
      _connecting = true;
      _status = 'در حال اتصال...';
    });

    try {
      final parser = FlutterV2ray.parseFromURL(link);

      final hasPermission = await _v2ray.requestPermission();

      if (!hasPermission) {
        throw Exception('مجوز VPN صادر نشد');
      }

      await _v2ray.startV2Ray(
        remark: parser.remark,
        config: parser.getFullConfiguration(),
        blockedApps: null,
        bypassSubnets: null,
        proxyOnly: false,
      );

      if (!mounted) return;
      setState(() {
        _connected = true;
        _status = 'درخواست اتصال ارسال شد';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _connected = false;
        _status = 'اتصال ناموفق بود؛ کانفیگ را بررسی کن';
      });
      _showMessage('اتصال برقرار نشد. لینک سرور را بررسی کن.');
    } finally {
      if (mounted) {
        setState(() => _connecting = false);
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _configController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: bg,
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(22),
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.shield_rounded,
                      color: green,
                      size: 28,
                    ),
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
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _showMessage('تنظیمات به‌زودی اضافه می‌شود');
                    },
                    icon: const Icon(
                      Icons.settings_outlined,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 36),

              // Connection card
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 28,
                ),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.06),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _connected ? 'متصل هستی' : 'محافظت از اتصال',
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
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Connect button
                    GestureDetector(
                      onTap: _toggleConnection,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 170,
                        height: 170,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: (_connected ? green : Colors.white)
                              .withValues(alpha: 0.06),
                          border: Border.all(
                            color: _connected
                                ? green
                                : Colors.white24,
                            width: 2,
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
                              ? const CircularProgressIndicator(
                            color: green,
                          )
                              : Icon(
                            Icons.power_settings_new_rounded,
                            size: 76,
                            color: _connected
                                ? green
                                : Colors.white70,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),
                    Text(
                      _connected ? 'قطع اتصال' : 'اتصال به VPN',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _initialized
                          ? 'برای شروع، دکمه بالا را لمس کن'
                          : 'در حال راه‌اندازی موتور VPN...',
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 26),

              // Config input
              const Text(
                'کانفیگ سرور',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'لینک VLESS یا VMess',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _configController,
                      enabled: !_connected && !_connecting,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      minLines: 2,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'vless://... یا vmess://...',
                        hintStyle: const TextStyle(
                          color: Colors.white30,
                        ),
                        filled: true,
                        fillColor: bg,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final data = await Clipboard.getData(
                            'text/plain',
                          );
                          if (data?.text != null && mounted) {
                            _configController.text =
                                data!.text!.trim();
                          }
                        },
                        icon: const Icon(Icons.content_paste_rounded),
                        label: const Text('چسباندن لینک کانفیگ'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: green,
                          side: const BorderSide(color: green),
                          padding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Account info
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: card,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Row(
                  children: [
                    Icon(
                      Icons.data_usage_rounded,
                      color: green,
                      size: 28,
                    ),
                    SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'مصرف اینترنت',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'پس از اتصال آمار مصرف را از API می‌گیریم',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
