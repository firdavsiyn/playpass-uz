import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/l10n/app_locale.dart';
import '../../../core/router/app_router.dart';
import '../../../core/utils/plural.dart';

enum ScanState { scanning, processing, success, error }

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // IMPORTANT: in a StatefulShellBranch the screen widget is kept alive across
  // tab switches — dispose() is NOT called when leaving the tab. mobile_scanner's
  // stop() only pauses the feed; on iOS the camera hardware (and the orange
  // privacy indicator) is only released by dispose(). So we make the controller
  // nullable and fully dispose/recreate on lifecycle boundaries.
  MobileScannerController? _scanner;
  ScanState _state = ScanState.scanning;
  String? _message;
  Map<String, dynamic>? _result;
  bool _processed = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _initScanner();
  }

  /// Create the controller and start the feed. No-op if already alive.
  void _initScanner() {
    if (_scanner != null) return;
    _scanner = MobileScannerController(
      formats: const [BarcodeFormat.qrCode],
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      autoStart: true,
    );
  }

  /// Fully release camera hardware. This is what actually clears the iOS
  /// privacy indicator — stop() alone is not enough.
  Future<void> _releaseScanner() async {
    final s = _scanner;
    _scanner = null;
    if (s == null) return;
    try {
      await s.stop();
    } catch (_) {}
    try {
      await s.dispose();
    } catch (_) {}
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Release on background — frees hardware + clears indicator.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _releaseScanner();
    }
    // Recreate on resume only if user is still on scanner & in scanning state.
    if (state == AppLifecycleState.resumed &&
        _scanner == null &&
        _state == ScanState.scanning) {
      _initScanner();
      if (mounted) setState(() {});
    }
  }

  @override
  void deactivate() {
    // Tab switch / navigation away — release everything.
    _releaseScanner();
    super.deactivate();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _releaseScanner();
    _pulseController.dispose();
    super.dispose();
  }

  Future<Position?> _getLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _onQrDetected(BarcodeCapture capture) async {
    if (_processed || _state != ScanState.scanning) return;
    final barcode = capture.barcodes.firstOrNull;
    final rawValue = barcode?.rawValue;
    if (rawValue == null || rawValue.isEmpty) return;

    _processed = true;
    setState(() => _state = ScanState.processing);
    // Release the camera the moment we have a valid code — clears iOS indicator
    // before the network call and overlay animation.
    await _releaseScanner();

    final raw = rawValue;

    // Parse deep link: playpassuz://checkin?z=ZONE_ID&h=QR_HMAC
    // Legacy format: playpassuz://checkin?c=CLUB_ID&t=QR_TOKEN
    try {
      final uri = Uri.parse(raw);
      if ((uri.scheme != 'playpassuz' && uri.scheme != 'gamepassuz') ||
          uri.host != 'checkin') {
        _setError(ref.lang('scan.invalid_qr'));
        return;
      }

      final zoneId = uri.queryParameters['z'] ?? uri.queryParameters['c'];
      final qrHmac = uri.queryParameters['h'] ?? uri.queryParameters['t'];

      if (zoneId == null || qrHmac == null) {
        _setError(ref.lang('scan.invalid_code'));
        return;
      }

      // Get geolocation
      final position = await _getLocation();

      // Perform checkin via Edge Function
      final service = SupabaseService();
      final result = await service.checkin(
        zoneId: zoneId,
        qrHmac: qrHmac,
        geoLat: position?.latitude,
        geoLon: position?.longitude,
      );

      HapticFeedback.heavyImpact();

      setState(() {
        _state = ScanState.success;
        _result = result;
        final visitsLeft = result['visits_remaining'] ?? result['hours_left'];
        _message = result['message'] as String? ??
            '${ref.lang('scan.welcome')} ${ref.lang('scan.hours_left')}: ${visitsLeft != null ? pluralVisits((visitsLeft as num).toInt()) : "?"}';
      });

      // Camera already released above. Just navigate after the result animation.
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) context.go('/home');
    } catch (e) {
      HapticFeedback.vibrate();
      _setError(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  void _setError(String msg) {
    setState(() {
      _state = ScanState.error;
      _message = msg;
    });
    Future.delayed(const Duration(seconds: 4), () async {
      if (!mounted) return;
      // Recreate scanner for retry (was released on detection).
      _initScanner();
      if (!mounted) return;
      setState(() {
        _state = ScanState.scanning;
        _message = null;
        _processed = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    // Watch tab index — scanner is tab 2
    final activeTab = ref.watch(activeTabIndexProvider);
    final isScannerTab = activeTab == 2;

    // Release camera when user switches away from scanner tab.
    // This is what clears the iOS privacy indicator on tab change.
    if (!isScannerTab && _scanner != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !isScannerTab) _releaseScanner();
      });
    }
    // Recreate camera when user switches back (only if still in scanning state).
    if (isScannerTab && _scanner == null && _state == ScanState.scanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _initScanner();
          setState(() => _processed = false);
        }
      });
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner — only mount when controller is alive
          if (_scanner != null &&
              (_state == ScanState.scanning || _state == ScanState.processing))
            MobileScanner(
              controller: _scanner!,
              onDetect: _onQrDetected,
            ),

          // Overlay
          _ScannerOverlay(state: _state),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () async {
                      await _releaseScanner();
                      if (context.mounted) context.go('/home');
                    },
                  ),
                  Expanded(
                    child: Text(
                      ref.lang('scan.title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    onPressed: () => _scanner?.toggleTorch(),
                  ),
                ],
              ),
            ),
          ),

          // Result overlay
          if (_state == ScanState.success || _state == ScanState.error)
            _ResultOverlay(
              state: _state,
              message: _message ?? '',
              result: _result,
            ),

          // Processing indicator
          if (_state == ScanState.processing)
            const Center(
              child: CircularProgressIndicator(color: AppTheme.primary),
            ),

          // Scan frame
          if (_state == ScanState.scanning)
            Center(
              child: AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (_, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: child,
                ),
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.7),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

          // Hint text
          if (_state == ScanState.scanning)
            Positioned(
              bottom: 100,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      ref.lang('scan.hint'),
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ScannerOverlay extends StatelessWidget {
  final ScanState state;
  const _ScannerOverlay({required this.state});

  @override
  Widget build(BuildContext context) {
    return ColorFiltered(
      colorFilter: ColorFilter.mode(
        Colors.black.withValues(
          alpha: state == ScanState.scanning ? 0.5 : 0.8,
        ),
        BlendMode.srcOver,
      ),
      child: CustomPaint(
        painter: _OverlayPainter(),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _OverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final center = Offset(size.width / 2, size.height / 2);
    const holeSize = 240.0;

    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: center, width: holeSize, height: holeSize),
        const Radius.circular(16),
      ),
      Paint()..blendMode = BlendMode.clear,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ResultOverlay extends ConsumerStatefulWidget {
  final ScanState state;
  final String message;
  final Map<String, dynamic>? result;

  const _ResultOverlay({
    required this.state,
    required this.message,
    this.result,
  });

  @override
  ConsumerState<_ResultOverlay> createState() => _ResultOverlayState();
}

class _ResultOverlayState extends ConsumerState<_ResultOverlay>
    with TickerProviderStateMixin {
  late ConfettiController _confetti;
  late AnimationController _scaleAnim;
  late AnimationController _counterAnim;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 2));
    _scaleAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _counterAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    if (widget.state == ScanState.success) {
      _confetti.play();
      _scaleAnim.forward();
      _counterAnim.forward();
    } else {
      _scaleAnim.value = 1.0;
    }
  }

  @override
  void dispose() {
    _confetti.dispose();
    _scaleAnim.dispose();
    _counterAnim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isSuccess = widget.state == ScanState.success;
    final color = isSuccess ? AppTheme.success : AppTheme.error;
    final icon = isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    final hoursLeft = ((widget.result?['visits_remaining'] ??
            widget.result?['hours_left']) as num?)
        ?.toInt();
    final clubName = (widget.result?['club_name'] as String?) ??
        (widget.result?['clubs']?['name'] as String?);

    return Container(
      color: Colors.black87,
      child: Stack(
        children: [
          // Confetti — top-center, blast 360°
          if (isSuccess)
            Align(
              alignment: Alignment.topCenter,
              child: ConfettiWidget(
                confettiController: _confetti,
                blastDirectionality: BlastDirectionality.explosive,
                emissionFrequency: 0.05,
                numberOfParticles: 30,
                gravity: 0.25,
                shouldLoop: false,
                colors: const [
                  AppTheme.primary,
                  AppTheme.neonCyan,
                  AppTheme.success,
                  AppTheme.neonPink,
                  Color(0xFFFFFFFF),
                ],
              ),
            ),

          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bouncy icon
                  ScaleTransition(
                    scale: CurvedAnimation(
                      parent: _scaleAnim,
                      curve: Curves.elasticOut,
                    ),
                    child: Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            color.withValues(alpha: 0.30),
                            color.withValues(alpha: 0.0),
                          ],
                        ),
                      ),
                      child: Center(
                        child: Icon(icon, color: color, size: 84),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Personalized welcome on success
                  if (isSuccess && clubName != null) ...[
                    Text(
                      ref.lang('scan.welcome'),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 14,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      clubName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ] else
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                  // Animated counter for remaining hours
                  if (isSuccess && hoursLeft != null) ...[
                    const SizedBox(height: 24),
                    AnimatedBuilder(
                      animation: _counterAnim,
                      builder: (context, _) {
                        final value =
                            (_counterAnim.value * hoursLeft).floor();
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.success.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: AppTheme.success.withValues(alpha: 0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  color: AppTheme.success, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                pluralVisits(value),
                                style: const TextStyle(
                                  color: AppTheme.success,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                ref.lang('scan.left'),
                                style: TextStyle(
                                  color:
                                      AppTheme.success.withValues(alpha: 0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],

                  if (!isSuccess) ...[
                    const SizedBox(height: 12),
                    Text(
                      widget.message,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 14),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
