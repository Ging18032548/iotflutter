import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:math' as math;
import 'mqtt_service.dart';
import 'home_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  MQTTService mqtt = MQTTService();
  HomeService data = HomeService();

  AnimationController? _pulseController;
  AnimationController? _bgController;
  Animation<double>? _pulseAnimation;
  Animation<double>? _bgAnimation;

  bool _connected = false;
  bool _monitoring = true;
  bool _ledRed = false;
  bool _ledYellow = true;
  bool _ledGreen = false;
  bool _buzzerState = false;
  bool _screenState = true;
  bool _autoMode = true;
  int _alertLevel = 1; // 1=low 2=mid 3=high

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.97, end: 1.03).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _bgAnimation = Tween<double>(begin: 0, end: 1).animate(_bgController!);

    mqtt.onData = (msg) {
      setState(() {
        data.update(msg);
        _connected = true;
      });
    };

    // ✅ ใช้ callback ผ่าน MQTTService — ไม่ override client.onConnected โดยตรง
    mqtt.onConnected = () => setState(() => _connected = true);
    mqtt.onDisconnected = () => setState(() => _connected = false);
    mqtt.connect();
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    _bgController?.dispose();
    super.dispose();
  }

  void _sendCommand(String cmd, dynamic value) {
    mqtt.publish('@msg/control', '{"cmd":"$cmd","value":$value}');
  }

  void _tap() => HapticFeedback.lightImpact();

  void _toggleMonitoring() {
    _tap();
    setState(() => _monitoring = !_monitoring);
    _sendCommand('monitor', _monitoring ? 'true' : 'false');
    if (_monitoring) {
      _pulseController?.repeat(reverse: true);
    } else {
      _pulseController?.stop();
    }
  }

  void _toggleLed(String color, bool current) {
    _tap();
    if (color == 'red') {
      setState(() => _ledRed = !current);
      _sendCommand('led_red', _ledRed ? 'true' : 'false');
    } else if (color == 'yellow') {
      setState(() => _ledYellow = !current);
      _sendCommand('led_yellow', _ledYellow ? 'true' : 'false');
    } else {
      setState(() => _ledGreen = !current);
      _sendCommand('led_green', _ledGreen ? 'true' : 'false');
    }
  }

  void _toggleBuzzer() {
    _tap();
    setState(() => _buzzerState = !_buzzerState);
    _sendCommand('buzzer', _buzzerState ? 'true' : 'false');
  }

  void _toggleScreen() {
    _tap();
    setState(() => _screenState = !_screenState);
    _sendCommand('screen', _screenState ? 'true' : 'false');
  }

  void _toggleAutoMode() {
    _tap();
    setState(() => _autoMode = !_autoMode);
    _sendCommand('auto', _autoMode ? 'true' : 'false');
  }

  void _setAlertLevel(int level) {
    _tap();
    setState(() => _alertLevel = level);
    _sendCommand('alert_level', '$level');
  }

  void _beepOnce() {
    _tap();
    _sendCommand('beep', '1');
    _showSnack('🔔 Beep 1 ครั้ง');
  }

  void _beepAlarm() {
    _tap();
    _sendCommand('beep', '3');
    _showSnack('🚨 Alarm 3 ครั้ง');
  }

  void _refreshData() {
    _tap();
    _sendCommand('refresh', 'true');
    _showSnack('🔄 ขอข้อมูลใหม่แล้ว');
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF1A2444),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Color get airColor {
    if (data.pm25 <= 25) return const Color(0xFF00E676);
    if (data.pm25 <= 50) return const Color(0xFFFFB300);
    return const Color(0xFFFF3D00);
  }

  List<Color> get airGradient {
    if (data.pm25 <= 25) return [const Color(0xFF00C853), const Color(0xFF69F0AE)];
    if (data.pm25 <= 50) return [const Color(0xFFFF6F00), const Color(0xFFFFD740)];
    return [const Color(0xFFD50000), const Color(0xFFFF6D00)];
  }

  String get airStatus {
    if (data.pm25 <= 25) return "GOOD";
    if (data.pm25 <= 50) return "MODERATE";
    return "UNHEALTHY";
  }

  String get airEmoji {
    if (data.pm25 <= 25) return "😊";
    if (data.pm25 <= 50) return "😐";
    return "😷";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _bgAnimation ?? kAlwaysCompleteAnimation,
        builder: (context, _) {
          final bgVal = _bgAnimation?.value ?? 0.0;
          return Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.lerp(const Color(0xFF080D1A), const Color(0xFF0D1B2A), bgVal)!,
                  Color.lerp(const Color(0xFF0D1228), const Color(0xFF1A0A2E), bgVal)!,
                  Color.lerp(const Color(0xFF0A0E27), const Color(0xFF080D1A), bgVal)!,
                ],
              ),
            ),
            child: SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    _buildHeader(),
                    const SizedBox(height: 28),
                    _buildMainGauge(),
                    const SizedBox(height: 24),
                    _buildMetricCards(),
                    const SizedBox(height: 20),
                    _buildSystemControls(),
                    const SizedBox(height: 16),
                    _buildLEDControls(),
                    const SizedBox(height: 16),
                    _buildBuzzerControls(),
                    const SizedBox(height: 16),
                    _buildAlertLevel(),
                    const SizedBox(height: 16),
                    _buildAQIScale(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Header ──────────────────────────────────

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (b) => const LinearGradient(
                colors: [Color(0xFF64B5F6), Color(0xFFCE93D8)],
              ).createShader(b),
              child: const Text("AIR QUALITY",
                  style: TextStyle(color: Colors.white, fontSize: 11, letterSpacing: 5, fontWeight: FontWeight.w700)),
            ),
            const Text("Monitor",
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w800)),
          ],
        ),
        Row(
          children: [
            // Refresh button
            GestureDetector(
              onTap: _refreshData,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                ),
                child: const Icon(Icons.refresh_rounded, color: Colors.white70, size: 20),
              ),
            ),
            const SizedBox(width: 8),
            // Live badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: _connected
                      ? [const Color(0xFF00C853), const Color(0xFF69F0AE)]
                      : [const Color(0xFF880E4F), const Color(0xFFE91E63)],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: (_connected ? const Color(0xFF00E676) : const Color(0xFFE91E63)).withValues(alpha: 0.4),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(width: 7, height: 7, decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white)),
                  const SizedBox(width: 5),
                  Text(_connected ? "LIVE" : "OFFLINE",
                      style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Gauge ────────────────────────────────────

  Widget _buildMainGauge() {
    final double progress = (data.pm25 / 150).clamp(0.0, 1.0);
    return Center(
      child: AnimatedBuilder(
        animation: _pulseAnimation ?? kAlwaysCompleteAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _monitoring ? (_pulseAnimation?.value ?? 1.0) : 1.0,
            child: SizedBox(
              width: 260, height: 260,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 260, height: 260,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(colors: [
                        airColor.withValues(alpha: 0.0),
                        airColor.withValues(alpha: 0.08),
                        airColor.withValues(alpha: 0.0),
                      ], stops: const [0.5, 0.8, 1.0]),
                    ),
                  ),
                  CustomPaint(
                    size: const Size(260, 260),
                    painter: ArcPainter(progress: 1.0, colors: [Colors.white10, Colors.white10], strokeWidth: 16),
                  ),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: progress),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (ctx, val, _) => CustomPaint(
                      size: const Size(260, 260),
                      painter: ArcPainter(progress: val, colors: airGradient, strokeWidth: 16, hasGlow: true),
                    ),
                  ),
                  Container(
                    width: 192, height: 192,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(colors: [Color(0xFF1E2A4A), Color(0xFF0F1628)]),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 20, spreadRadius: 5)],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(airEmoji, style: const TextStyle(fontSize: 32)),
                        TweenAnimationBuilder<int>(
                          tween: IntTween(begin: 0, end: data.pm25),
                          duration: const Duration(milliseconds: 900),
                          builder: (ctx, val, _) => ShaderMask(
                            shaderCallback: (b) => LinearGradient(colors: airGradient).createShader(b),
                            child: Text("$val",
                                style: const TextStyle(color: Colors.white, fontSize: 56, fontWeight: FontWeight.w900, height: 1.0)),
                          ),
                        ),
                        Text("µg/m³  •  PM2.5",
                            style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11, letterSpacing: 1)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: airGradient),
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [BoxShadow(color: airColor.withValues(alpha: 0.4), blurRadius: 10)],
                          ),
                          child: Text(airStatus,
                              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 2.5)),
                        ),
                      ],
                    ),
                  ),
                  if (!_monitoring)
                    Container(
                      width: 192, height: 192,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.black.withValues(alpha: 0.6),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.pause_circle_outline, color: Colors.white60, size: 48),
                          SizedBox(height: 6),
                          Text("PAUSED", style: TextStyle(color: Colors.white60, fontSize: 12, letterSpacing: 3)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Metric Cards ─────────────────────────────

  Widget _buildMetricCards() {
    return Row(
      children: [
        Expanded(child: _MetricCard(
          icon: Icons.thermostat_rounded,
          label: "Temperature",
          value: data.temperature.toStringAsFixed(1),
          unit: "°C",
          gradient: [const Color(0xFFFF6B6B), const Color(0xFFFF8E53)],
        )),
        const SizedBox(width: 12),
        Expanded(child: _MetricCard(
          icon: Icons.water_drop_rounded,
          label: "Humidity",
          value: data.humidity.toStringAsFixed(1),
          unit: "%",
          gradient: [const Color(0xFF4FC3F7), const Color(0xFF1565C0)],
        )),
      ],
    );
  }

  // ── Section Header ───────────────────────────

  Widget _sectionHeader(String title, IconData icon, List<Color> gradient) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: gradient),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Text(title,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
      ],
    );
  }

  Widget _panelContainer({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2444), Color(0xFF0F1628)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }

  // ── System Controls ──────────────────────────

  Widget _buildSystemControls() {
    return _panelContainer(
      child: Column(
        children: [
          _sectionHeader("SYSTEM", Icons.settings_remote_rounded, [const Color(0xFF7C4DFF), const Color(0xFF448AFF)]),
          const SizedBox(height: 16),

          // Monitor toggle (big)
          _BigToggle(
            label: "Monitoring",
            subtitle: _monitoring ? "กำลังรับข้อมูลอยู่" : "หยุดรับข้อมูลชั่วคราว",
            icon: Icons.monitor_heart_rounded,
            isOn: _monitoring,
            onToggle: _toggleMonitoring,
            gradient: _monitoring
                ? [const Color(0xFF00C853), const Color(0xFF69F0AE)]
                : [const Color(0xFF37474F), const Color(0xFF546E7A)],
          ),
          const SizedBox(height: 10),

          // Auto mode toggle (big)
          _BigToggle(
            label: "Auto Mode",
            subtitle: _autoMode ? "ระบบควบคุม LED อัตโนมัติ" : "ควบคุม LED เอง",
            icon: Icons.auto_mode_rounded,
            isOn: _autoMode,
            onToggle: _toggleAutoMode,
            gradient: _autoMode
                ? [const Color(0xFF00BCD4), const Color(0xFF1565C0)]
                : [const Color(0xFF37474F), const Color(0xFF546E7A)],
          ),
          const SizedBox(height: 10),

          // Screen + Quick action row
          Row(
            children: [
              Expanded(
                child: _SmallToggle(
                  label: "TFT Screen",
                  icon: Icons.tv_rounded,
                  isOn: _screenState,
                  onToggle: _toggleScreen,
                  gradient: [const Color(0xFF00BFA5), const Color(0xFF64FFDA)],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _refreshData,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF7C4DFF), Color(0xFF448AFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: const Color(0xFF7C4DFF).withValues(alpha: 0.4), blurRadius: 14)],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.refresh_rounded, color: Colors.white, size: 26),
                        SizedBox(height: 6),
                        Text("Refresh", style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                        SizedBox(height: 4),
                        Text("ขอข้อมูลใหม่", style: TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── LED Controls ─────────────────────────────

  Widget _buildLEDControls() {
    return _panelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("LED CONTROL", Icons.lightbulb_rounded, [const Color(0xFFFFD600), const Color(0xFFFF6D00)]),
          const SizedBox(height: 6),
          if (_autoMode)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: Colors.orange, size: 14),
                  SizedBox(width: 6),
                  Text("Auto Mode เปิดอยู่ — LED ถูกควบคุมอัตโนมัติ",
                      style: TextStyle(color: Colors.orange, fontSize: 11)),
                ],
              ),
            )
          else ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _LedButton(
                    label: "RED",
                    icon: Icons.circle,
                    isOn: _ledRed,
                    color: const Color(0xFFFF1744),
                    onToggle: () => _toggleLed('red', _ledRed),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LedButton(
                    label: "YELLOW",
                    icon: Icons.circle,
                    isOn: _ledYellow,
                    color: const Color(0xFFFFD600),
                    onToggle: () => _toggleLed('yellow', _ledYellow),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _LedButton(
                    label: "GREEN",
                    icon: Icons.circle,
                    isOn: _ledGreen,
                    color: const Color(0xFF00E676),
                    onToggle: () => _toggleLed('green', _ledGreen),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  // ── Buzzer Controls ──────────────────────────

  Widget _buildBuzzerControls() {
    return _panelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("BUZZER", Icons.volume_up_rounded, [const Color(0xFFE91E63), const Color(0xFF9C27B0)]),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _BigToggle(
                  label: "Buzzer",
                  subtitle: _buzzerState ? "เปิดอยู่" : "ปิดอยู่",
                  icon: Icons.notifications_active_rounded,
                  isOn: _buzzerState,
                  onToggle: _toggleBuzzer,
                  gradient: _buzzerState
                      ? [const Color(0xFFE91E63), const Color(0xFF9C27B0)]
                      : [const Color(0xFF37474F), const Color(0xFF546E7A)],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: _beepOnce,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF00BCD4), Color(0xFF006064)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFF00BCD4).withValues(alpha: 0.35), blurRadius: 12)],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.notifications_rounded, color: Colors.white, size: 24),
                        SizedBox(height: 4),
                        Text("Beep 1×", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: _beepAlarm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF1744), Color(0xFFD500F9)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [BoxShadow(color: const Color(0xFFFF1744).withValues(alpha: 0.35), blurRadius: 12)],
                    ),
                    child: const Column(
                      children: [
                        Icon(Icons.notification_important_rounded, color: Colors.white, size: 24),
                        SizedBox(height: 4),
                        Text("Alarm 3×", style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Alert Level ──────────────────────────────

  Widget _buildAlertLevel() {
    return _panelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("ALERT LEVEL", Icons.warning_amber_rounded, [const Color(0xFFFF6F00), const Color(0xFFFFD740)]),
          const SizedBox(height: 16),
          Row(
            children: [
              _AlertChip(level: 1, label: "LOW\n≤ 25", color: const Color(0xFF00E676), current: _alertLevel, onTap: _setAlertLevel),
              const SizedBox(width: 8),
              _AlertChip(level: 2, label: "MED\n≤ 50", color: const Color(0xFFFFB300), current: _alertLevel, onTap: _setAlertLevel),
              const SizedBox(width: 8),
              _AlertChip(level: 3, label: "HIGH\n51+", color: const Color(0xFFFF3D00), current: _alertLevel, onTap: _setAlertLevel),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.white38, size: 14),
                const SizedBox(width: 8),
                Text(
                  _alertLevel == 1
                      ? "แจ้งเตือนเมื่อ PM2.5 เกิน 25 µg/m³"
                      : _alertLevel == 2
                          ? "แจ้งเตือนเมื่อ PM2.5 เกิน 50 µg/m³"
                          : "แจ้งเตือนเมื่อ PM2.5 เกิน 100 µg/m³",
                  style: TextStyle(color: Colors.white54, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── AQI Scale ────────────────────────────────

  Widget _buildAQIScale() {
    return _panelContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionHeader("PM2.5 INDEX", Icons.bar_chart_rounded, [const Color(0xFF00BFA5), const Color(0xFF64FFDA)]),
          const SizedBox(height: 14),
          Row(
            children: [
              _ScaleChip(range: "0–25", label: "Good",
                  gradient: [const Color(0xFF00C853), const Color(0xFF69F0AE)], isActive: data.pm25 <= 25),
              const SizedBox(width: 8),
              _ScaleChip(range: "26–50", label: "Moderate",
                  gradient: [const Color(0xFFFF6F00), const Color(0xFFFFD740)], isActive: data.pm25 > 25 && data.pm25 <= 50),
              const SizedBox(width: 8),
              _ScaleChip(range: "51+", label: "Unhealthy",
                  gradient: [const Color(0xFFD50000), const Color(0xFFFF6D00)], isActive: data.pm25 > 50),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Reusable Widgets
// ─────────────────────────────────────────────

class _BigToggle extends StatelessWidget {
  final String label, subtitle;
  final IconData icon;
  final bool isOn;
  final VoidCallback onToggle;
  final List<Color> gradient;

  const _BigToggle({
    required this.label, required this.subtitle, required this.icon,
    required this.isOn, required this.onToggle, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: isOn ? gradient : [Colors.white.withValues(alpha: 0.05), Colors.white.withValues(alpha: 0.03)]),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isOn ? gradient.first.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
          boxShadow: isOn ? [BoxShadow(color: gradient.first.withValues(alpha: 0.3), blurRadius: 14)] : [],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isOn ? Colors.white.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isOn ? Colors.white : Colors.white38, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(color: isOn ? Colors.white : Colors.white38, fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(subtitle, style: TextStyle(color: isOn ? Colors.white70 : Colors.white24, fontSize: 11)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: 50, height: 26,
              decoration: BoxDecoration(
                color: isOn ? Colors.white.withValues(alpha: 0.25) : Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(13),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                alignment: isOn ? Alignment.centerRight : Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: isOn ? Colors.white : Colors.white38,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 4)],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SmallToggle extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isOn;
  final VoidCallback onToggle;
  final List<Color> gradient;

  const _SmallToggle({
    required this.label, required this.icon, required this.isOn,
    required this.onToggle, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: isOn ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient) : null,
          color: isOn ? null : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isOn ? gradient.first.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.08)),
          boxShadow: isOn ? [BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 14)] : [],
        ),
        child: Column(
          children: [
            Icon(icon, color: isOn ? Colors.white : Colors.white38, size: 26),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: isOn ? Colors.white : Colors.white38, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(isOn ? "ON" : "OFF",
                style: TextStyle(color: isOn ? Colors.white70 : Colors.white24, fontSize: 9, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _LedButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isOn;
  final Color color;
  final VoidCallback onToggle;

  const _LedButton({
    required this.label, required this.icon, required this.isOn,
    required this.color, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          color: isOn ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isOn ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08), width: isOn ? 1.5 : 1),
          boxShadow: isOn ? [BoxShadow(color: color.withValues(alpha: 0.45), blurRadius: 16, spreadRadius: 1)] : [],
        ),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 28, height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isOn ? color : Colors.white.withValues(alpha: 0.1),
                boxShadow: isOn ? [BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 12, spreadRadius: 2)] : [],
              ),
            ),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(color: isOn ? color : Colors.white38, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1)),
            const SizedBox(height: 3),
            Text(isOn ? "ON" : "OFF",
                style: TextStyle(color: isOn ? color.withValues(alpha: 0.7) : Colors.white24, fontSize: 9, letterSpacing: 1.5)),
          ],
        ),
      ),
    );
  }
}

class _AlertChip extends StatelessWidget {
  final int level, current;
  final String label;
  final Color color;
  final Function(int) onTap;

  const _AlertChip({
    required this.level, required this.label, required this.color,
    required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isActive = current == level;
    return Expanded(
      child: GestureDetector(
        onTap: () => onTap(level),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isActive ? color.withValues(alpha: 0.18) : Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isActive ? color.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08), width: isActive ? 1.5 : 1),
            boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: 0.35), blurRadius: 12)] : [],
          ),
          child: Column(
            children: [
              Icon(isActive ? Icons.warning_rounded : Icons.warning_amber_outlined,
                  color: isActive ? color : Colors.white38, size: 22),
              const SizedBox(height: 6),
              Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: isActive ? color : Colors.white38, fontSize: 10, fontWeight: FontWeight.w800, height: 1.4)),
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label, value, unit;
  final List<Color> gradient;

  const _MetricCard({
    required this.icon, required this.label, required this.value,
    required this.unit, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
            colors: [Color(0xFF1A2444), Color(0xFF0F1628)]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: 2)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: gradient),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 10)],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 14),
          ShaderMask(
            shaderCallback: (b) => LinearGradient(colors: gradient).createShader(b),
            child: Text("$value$unit",
                style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1)),
          ),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 12)),
        ],
      ),
    );
  }
}

class _ScaleChip extends StatelessWidget {
  final String range, label;
  final List<Color> gradient;
  final bool isActive;

  const _ScaleChip({
    required this.range, required this.label, required this.gradient, required this.isActive});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isActive ? LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: gradient) : null,
          color: isActive ? null : Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: isActive ? gradient.first.withValues(alpha: 0.6) : Colors.white.withValues(alpha: 0.08)),
          boxShadow: isActive ? [BoxShadow(color: gradient.first.withValues(alpha: 0.4), blurRadius: 12)] : [],
        ),
        child: Column(
          children: [
            Text(range, style: TextStyle(color: isActive ? Colors.white : Colors.white38, fontSize: 10, fontWeight: FontWeight.w800)),
            const SizedBox(height: 3),
            Text(label, style: TextStyle(color: isActive ? Colors.white70 : Colors.white24, fontSize: 9)),
          ],
        ),
      ),
    );
  }
}

// ── Arc Painter ──────────────────────────────

class ArcPainter extends CustomPainter {
  final double progress;
  final List<Color> colors;
  final double strokeWidth;
  final bool hasGlow;

  ArcPainter({required this.progress, required this.colors, required this.strokeWidth, this.hasGlow = false});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    const startAngle = -math.pi * 0.75;
    final sweepAngle = math.pi * 1.5 * progress;
    final rect = Rect.fromCircle(center: center, radius: radius);

    if (hasGlow && progress > 0) {
      canvas.drawArc(rect, startAngle, sweepAngle, false,
          Paint()
            ..shader = SweepGradient(colors: colors, startAngle: startAngle, endAngle: startAngle + sweepAngle).createShader(rect)
            ..strokeWidth = strokeWidth + 12
            ..style = PaintingStyle.stroke
            ..strokeCap = StrokeCap.round
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8));
    }

    canvas.drawArc(rect, startAngle, sweepAngle, false,
        Paint()
          ..shader = SweepGradient(colors: colors, startAngle: startAngle, endAngle: startAngle + sweepAngle + 0.001).createShader(rect)
          ..strokeWidth = strokeWidth
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(ArcPainter old) => old.progress != progress || old.colors != colors;
}