import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/app_identity.dart';
import '../theme/app_theme.dart';
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
    return const SizedBox.square(
      dimension: 246,
      child: BrandMark(
        key: Key('splash-pictogram'),
        size: 246,
        onDarkBackground: true,
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
