import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/app_theme.dart';

// ---------------------------------------------------------------------------
// Data model for each onboarding slide
// ---------------------------------------------------------------------------
class _SlideData {
  final String title;
  final String subtitle;
  final List<Color> gradient;
  final Color particleTint;

  const _SlideData({
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.particleTint,
  });
}

// ---------------------------------------------------------------------------
// Main screen
// ---------------------------------------------------------------------------
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final _controller = PageController(viewportFraction: 1.0);
  int _page = 0;

  // Animation controllers
  late final AnimationController _ringController;
  late final AnimationController _scanController;
  late final AnimationController _pulseController;
  late final AnimationController _particleController;

  static const _slides = [
    _SlideData(
      title: 'Один абонемент —\n50+ клубов',
      subtitle:
          'Купи месячную подписку и ходи в любой клуб сети без наличных. PlayPass — один QR, все клубы.',
      gradient: [Color(0xFF6366F1), Color(0xFF4F46E5)],
      particleTint: Color(0xFF818CF8),
    ),
    _SlideData(
      title: 'Просто сканируй\nQR',
      subtitle:
          'Найди клуб в приложении, приди и отсканируй QR-постер на входе. Чекин за 3 секунды!',
      gradient: [Color(0xFF2563EB), Color(0xFF1D4ED8)],
      particleTint: Color(0xFF06B6D4),
    ),
    _SlideData(
      title: 'Выбери\nсвой тариф',
      subtitle:
          'От 149K UZS/мес. Базовый, Стандарт, Про или VIP — в зависимости от твоего ритма игры.',
      gradient: [Color(0xFFF59E0B), Color(0xFFD97706)],
      particleTint: Color(0xFFFBBF24),
    ),
  ];

  @override
  void initState() {
    super.initState();

    _ringController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ringController.dispose();
    _scanController.dispose();
    _pulseController.dispose();
    _particleController.dispose();
    super.dispose();
  }

  // ── Navigation (preserved) ──────────────────────────────────

  Future<void> _next() async {
    if (_page < _slides.length - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );
    } else {
      await _markOnboardingSeen();
      if (mounted) context.go('/auth/profile-setup');
    }
  }

  Future<void> _skip() async {
    await _markOnboardingSeen();
    if (mounted) context.go('/auth/profile-setup');
  }

  Future<void> _markOnboardingSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('onboarding_seen', true);
  }

  // ── Build ───────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_page];

    return Scaffold(
      backgroundColor: context.bg,
      body: Stack(
        children: [
          // Animated background particles
          Positioned.fill(
            child: _FloatingParticles(
              controller: _particleController,
              tint: slide.particleTint,
            ),
          ),

          // Radial glow behind icon area
          Positioned(
            top: MediaQuery.of(context).size.height * 0.18,
            left: 0,
            right: 0,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      slide.gradient[0].withValues(alpha: 0.18),
                      slide.gradient[1].withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Main content
          SafeArea(
            child: Column(
              children: [
                // Skip button — top-right, subtle
                Align(
                  alignment: Alignment.topRight,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: TextButton(
                      onPressed: _skip,
                      child: Text(
                        'Пропустить',
                        style: TextStyle(
                          color: context.text3,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                ),

                // PageView
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    physics: const BouncingScrollPhysics(),
                    onPageChanged: (i) => setState(() => _page = i),
                    itemCount: _slides.length,
                    itemBuilder: (_, i) => _SlideContent(
                      slide: _slides[i],
                      index: i,
                      ringController: _ringController,
                      scanController: _scanController,
                      pulseController: _pulseController,
                      isActive: _page == i,
                    ),
                  ),
                ),

                // Animated dot indicators
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (i) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _page == i ? 24 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _page == i
                            ? AppTheme.primary
                            : context.text3.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // CTA button — gradient with glow
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GestureDetector(
                    onTap: _next,
                    child: Container(
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, Color(0xFF6366F1)],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color:
                                const Color(0xFF6366F1).withValues(alpha: 0.2),
                            blurRadius: 40,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          _page == _slides.length - 1
                              ? 'Начать играть \u2192'
                              : 'Далее \u2192',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Slide content (icon + text)
// ---------------------------------------------------------------------------
class _SlideContent extends StatelessWidget {
  final _SlideData slide;
  final int index;
  final AnimationController ringController;
  final AnimationController scanController;
  final AnimationController pulseController;
  final bool isActive;

  const _SlideContent({
    required this.slide,
    required this.index,
    required this.ringController,
    required this.scanController,
    required this.pulseController,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Animated icon — different per page
          SizedBox(
            width: 160,
            height: 160,
            child: _buildAnimatedIcon(),
          ),
          const SizedBox(height: 44),

          // Title
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.text1,
              fontSize: 26,
              fontWeight: FontWeight.w800,
              height: 1.2,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 18),

          // Subtitle
          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: context.text2,
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnimatedIcon() {
    switch (index) {
      case 0:
        return _RotatingRingIcon(controller: ringController);
      case 1:
        return _ScanningQRIcon(controller: scanController);
      case 2:
        return _PulsingDiamondIcon(
            controller: pulseController, isActive: isActive);
      default:
        return const SizedBox.shrink();
    }
  }
}

// ---------------------------------------------------------------------------
// Page 1: Rotating gradient ring + gamepad icon
// ---------------------------------------------------------------------------
class _RotatingRingIcon extends StatelessWidget {
  final AnimationController controller;
  const _RotatingRingIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Transform.rotate(
          angle: controller.value * 2 * math.pi,
          child: Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: const [
                  Color(0xFF6366F1),
                  Color(0xFF8B5CF6),
                  Color(0xFF06B6D4),
                  Color(0xFFA78BFA),
                  Color(0xFF6366F1),
                ],
                transform: GradientRotation(controller.value * 2 * math.pi),
              ),
            ),
            padding: const EdgeInsets.all(4),
            child: child,
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: context.bg,
        ),
        child: Center(
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFF6366F1).withValues(alpha: 0.12),
            ),
            child: const Icon(
              Icons.sports_esports_rounded,
              size: 48,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 2: QR code with scanning line
// ---------------------------------------------------------------------------
class _ScanningQRIcon extends StatelessWidget {
  final AnimationController controller;
  const _ScanningQRIcon({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: 130,
        height: 130,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            Container(
              width: 130,
              height: 130,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF06B6D4).withValues(alpha: 0.10),
                border: Border.all(
                  color: const Color(0xFF06B6D4).withValues(alpha: 0.20),
                  width: 1.5,
                ),
              ),
            ),

            // QR icon
            const Icon(
              Icons.qr_code_2_rounded,
              size: 56,
              color: Colors.white,
            ),

            // Scanning line
            AnimatedBuilder(
              animation: controller,
              builder: (context, _) {
                final top = 20 + (controller.value * 90);
                return Positioned(
                  top: top,
                  left: 20,
                  right: 20,
                  child: Container(
                    height: 2.5,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          const Color(0xFF10B981).withValues(alpha: 0.9),
                          const Color(0xFF06B6D4),
                          const Color(0xFF10B981).withValues(alpha: 0.9),
                          Colors.transparent,
                        ],
                        stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.5),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Page 3: Pulsing diamond with bounce entrance
// ---------------------------------------------------------------------------
class _PulsingDiamondIcon extends StatefulWidget {
  final AnimationController controller;
  final bool isActive;
  const _PulsingDiamondIcon({required this.controller, required this.isActive});

  @override
  State<_PulsingDiamondIcon> createState() => _PulsingDiamondIconState();
}

class _PulsingDiamondIconState extends State<_PulsingDiamondIcon>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bounceController;
  late final Animation<double> _bounceAnim;
  bool _hasAnimated = false;

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _bounceAnim = CurvedAnimation(
      parent: _bounceController,
      curve: Curves.elasticOut,
    );
  }

  @override
  void didUpdateWidget(covariant _PulsingDiamondIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isActive && !_hasAnimated) {
      _hasAnimated = true;
      _bounceController.forward(from: 0);
    }
    if (!widget.isActive) {
      _hasAnimated = false;
      _bounceController.reset();
    }
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([widget.controller, _bounceAnim]),
      builder: (context, _) {
        final pulse = 1.0 + (widget.controller.value * 0.08);
        final bounceScale = _bounceAnim.value;
        final glowOpacity = 0.15 + (widget.controller.value * 0.15);

        return Transform.scale(
          scale: bounceScale * pulse,
          child: Container(
            width: 130,
            height: 130,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF59E0B).withValues(alpha: 0.10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFBBF24).withValues(alpha: glowOpacity),
                  blurRadius: 40,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.diamond_rounded,
                size: 56,
                color: Color(0xFFFBBF24),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Floating particles background
// ---------------------------------------------------------------------------
class _FloatingParticles extends StatelessWidget {
  final AnimationController controller;
  final Color tint;
  const _FloatingParticles({required this.controller, required this.tint});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return CustomPaint(
          painter: _ParticlePainter(
            progress: controller.value,
            tint: tint,
            screenSize: MediaQuery.of(context).size,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double progress;
  final Color tint;
  final Size screenSize;

  // 7 particles with fixed pseudo-random positions
  static const _particleCount = 7;

  _ParticlePainter({
    required this.progress,
    required this.tint,
    required this.screenSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42); // deterministic seed for stable positions

    for (int i = 0; i < _particleCount; i++) {
      final baseX = rng.nextDouble() * size.width;
      final baseY = rng.nextDouble() * size.height;
      final radius = 2.0 + rng.nextDouble() * 3.0;
      final speed = 0.6 + rng.nextDouble() * 0.4;
      final phase = rng.nextDouble() * 2 * math.pi;

      // Float upward and drift horizontally
      final t = (progress * speed + phase) % 1.0;
      final y = baseY - (t * size.height * 0.3);
      final x = baseX + math.sin(t * 2 * math.pi + phase) * 20;

      // Fade in/out as they travel
      final alpha = (math.sin(t * math.pi) * 0.5).clamp(0.0, 1.0);

      final paint = Paint()
        ..color = tint.withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5);

      canvas.drawCircle(Offset(x % size.width, y % size.height), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.tint != tint;
  }
}
