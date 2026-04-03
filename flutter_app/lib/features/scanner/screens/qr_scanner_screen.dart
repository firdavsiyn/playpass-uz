import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/supabase_service.dart';
import '../../../core/theme/app_theme.dart';

enum ScanState { scanning, processing, success, error }

class QrScannerScreen extends ConsumerStatefulWidget {
  const QrScannerScreen({super.key});

  @override
  ConsumerState<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends ConsumerState<QrScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _scanner = MobileScannerController();
  ScanState _state = ScanState.scanning;
  String? _message;
  Map<String, dynamic>? _result;
  bool _processed = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    _pulseAnimation = Tween(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scanner.dispose();
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
    if (barcode?.rawValue == null) return;

    _processed = true;
    setState(() => _state = ScanState.processing);
    _scanner.stop();

    final raw = barcode!.rawValue!;

    // Parse deep link: playpassuz://checkin?z=ZONE_ID&h=QR_HMAC
    // Legacy format: playpassuz://checkin?c=CLUB_ID&t=QR_TOKEN
    try {
      final uri = Uri.parse(raw);
      if ((uri.scheme != 'playpassuz' && uri.scheme != 'gamepassuz') ||
          uri.host != 'checkin') {
        _setError('Неверный QR-код. Отсканируйте постер PlayPass.');
        return;
      }

      final zoneId = uri.queryParameters['z'] ?? uri.queryParameters['c'];
      final qrHmac = uri.queryParameters['h'] ?? uri.queryParameters['t'];

      if (zoneId == null || qrHmac == null) {
        _setError('Недействительный QR-код.');
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
        _message = result['message'] as String? ??
            'Добро пожаловать! Осталось: ${result['hours_left'] ?? "?"} ч';
      });

      // Auto-close after 3 seconds
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
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _state = ScanState.scanning;
          _message = null;
          _processed = false;
        });
        _scanner.start();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Scanner
          if (_state == ScanState.scanning || _state == ScanState.processing)
            MobileScanner(
              controller: _scanner,
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
                    icon:
                        const Icon(Icons.arrow_back_ios, color: Colors.white),
                    onPressed: () => context.go('/home'),
                  ),
                  const Expanded(
                    child: Text(
                      'Сканировать QR',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.flash_on, color: Colors.white),
                    onPressed: () => _scanner.toggleTorch(),
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
                    child: const Text(
                      'Наведите на QR-постер клуба',
                      style: TextStyle(color: Colors.white, fontSize: 15),
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

class _ResultOverlay extends StatelessWidget {
  final ScanState state;
  final String message;
  final Map<String, dynamic>? result;

  const _ResultOverlay({
    required this.state,
    required this.message,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    final isSuccess = state == ScanState.success;
    final color = isSuccess ? AppTheme.success : AppTheme.error;
    final icon =
        isSuccess ? Icons.check_circle_rounded : Icons.error_rounded;

    return Container(
      color: Colors.black87,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 80),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (isSuccess && result != null) ...[
                const SizedBox(height: 16),
                if (result!['hours_left'] != null)
                  Text(
                    'Осталось: ${result!['hours_left']} ч',
                    style: const TextStyle(
                        color: AppTheme.textSecondary, fontSize: 16),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
