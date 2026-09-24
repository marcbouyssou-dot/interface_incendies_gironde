import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart' show AppTheme;
import '../theme/v5_foundation.dart';
import '../utils/system_theme.dart';
import '../widgets/brand_mark.dart';

typedef SplashVisualPreparation = Future<void> Function(BuildContext context);

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.prepareVisuals, this.onComposed});

  final SplashVisualPreparation? prepareVisuals;
  final VoidCallback? onComposed;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _preparationStarted = false;
  bool _composed = false;
  bool _compositionReported = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_preparationStarted) return;
    _preparationStarted = true;
    _prepareVisuals();
  }

  Future<void> _prepareVisuals() async {
    try {
      await (widget.prepareVisuals?.call(context) ??
          _precacheSplashAssets(context));
    } catch (error, stackTrace) {
      debugPrint('Préchargement visuel du splash impossible : $error');
      debugPrintStack(stackTrace: stackTrace);
    }
    if (!mounted) return;
    setState(() => _composed = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _compositionReported) return;
      _compositionReported = true;
      markFlutterSplashComposed();
      widget.onComposed?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.splashSystemUiOverlayStyle,
      child: Scaffold(
        backgroundColor: V5Colors.light.brand,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final contentHeight = (constraints.maxHeight - V5Spacing.xxl * 2)
                  .clamp(0.0, double.infinity);
              return SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: V5Spacing.xl,
                  vertical: V5Spacing.xxl,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: contentHeight),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Visibility(
                        key: const Key('splash-composed-identity'),
                        visible: _composed,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: const _SplashIdentity(),
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

Future<void> _precacheSplashAssets(BuildContext context) => Future.wait([
  precacheImage(const AssetImage(AppIdentity.pictogramAsset), context),
  precacheImage(const AssetImage(AppIdentity.mobilizationSymbolAsset), context),
]);

class _SplashIdentity extends StatelessWidget {
  const _SplashIdentity();

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SplashPictogram(),
        SizedBox(height: V5Spacing.xl),
        Text(
          AppIdentity.productName,
          key: Key('splash-product-name'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            height: 1.15,
            letterSpacing: -0.8,
            fontWeight: FontWeight.w700,
          ),
        ),
        SizedBox(height: V5Spacing.xs),
        Text(
          AppIdentity.mobilizationSubtitle,
          key: Key('splash-mobilization-subtitle'),
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Color(0xFFD9E3F1),
            fontSize: 20,
            height: 1.4,
            fontWeight: FontWeight.w400,
          ),
        ),
        SizedBox(height: V5Spacing.xxxl),
        _InstitutionalSignature(),
      ],
    );
  }
}

class _SplashPictogram extends StatelessWidget {
  const _SplashPictogram();

  @override
  Widget build(BuildContext context) {
    return const BrandMark(
      key: Key('splash-pictogram'),
      size: 216,
      onDarkBackground: true,
    );
  }
}

class _InstitutionalSignature extends StatelessWidget {
  const _InstitutionalSignature();

  @override
  Widget build(BuildContext context) {
    return const Text(
      AppIdentity.institutionalSignature,
      key: Key('splash-institutional-signature'),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Color(0xFFD9E3F1),
        fontSize: 14,
        height: 1.4,
        letterSpacing: 1.6,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
