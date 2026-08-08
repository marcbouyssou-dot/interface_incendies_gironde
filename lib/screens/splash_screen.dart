import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
import '../utils/system_theme.dart';
import '../widgets/brand_mark.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _scale;
  late final Animation<Offset> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppIdentity.splashRevealDuration,
    );
    final reveal = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    _opacity = reveal;
    _scale = Tween<double>(begin: .985, end: 1).animate(reveal);
    _slide = Tween<Offset>(
      begin: const Offset(0, .025),
      end: Offset.zero,
    ).animate(reveal);
    _controller.forward().whenComplete(dismissNativeStartupSplash);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.darkSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: AppColors.navy,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              const horizontalPadding = 28.0;
              final contentHeight = constraints.maxHeight - 40;
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: FadeTransition(
                        key: const Key('splash-animated-identity'),
                        opacity: _opacity,
                        child: ScaleTransition(
                          scale: _scale,
                          child: SlideTransition(
                            position: _slide,
                            child: const _SplashIdentity(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _SplashIdentity extends StatelessWidget {
  const _SplashIdentity();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SplashPictogram(),
        SizedBox(height: 30),
        Text(
          AppIdentity.productName,
          key: Key('splash-product-name'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 42,
            height: 1.05,
            letterSpacing: -1.1,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 10),
        Text(
          AppIdentity.mobilizationSubtitle,
          key: Key('splash-mobilization-subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD9E3F1),
            fontSize: 20,
            height: 1.25,
            letterSpacing: 0.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        SizedBox(height: 58),
        _InstitutionalSignature(),
      ],
    );
  }
}

class _SplashPictogram extends StatelessWidget {
  const _SplashPictogram();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Pictogramme MobSanté',
      image: true,
      child: SizedBox.square(
        dimension: 246,
        child: const BrandMark(
          key: Key('splash-pictogram'),
          size: 246,
          onDarkBackground: true,
        ),
      ),
    );
  }
}

class _InstitutionalSignature extends StatelessWidget {
  const _InstitutionalSignature();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: Colors.white24)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            AppIdentity.institutionalSignature,
            key: Key('splash-institutional-signature'),
            style: TextStyle(
              color: Color(0xFF58A5FF),
              fontSize: 14,
              letterSpacing: 3.2,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: Colors.white24)),
      ],
    );
  }
}
